/**
 * OPFS (Origin Private File System) Helper for Flutter Edge AI
 *
 * Provides OPFS-based storage for large model files (>2GB) to bypass
 * ArrayBuffer memory limitations in browsers.
 *
 * Key features:
 * - Download large files directly to OPFS with streaming
 * - Check if models are already cached
 * - Get ReadableStreamDefaultReader for MediaPipe streaming
 * - Storage quota management
 * - Cross-browser write support: createWritable() where available,
 *   createSyncAccessHandle() in a dedicated worker on Safari/WebKit <= 18
 *
 * Browser support:
 * - Chrome 86+, Edge 86+, Firefox 111+: createWritable() available
 * - Safari 15.2-18 / iOS 15-18: OPFS exists but NO createWritable()
 *   -> a dedicated worker uses createSyncAccessHandle() instead
 * - Safari 26+ / iOS 26+: createWritable() available
 */

window.flutterGemmaOPFS = (function () {
  'use strict';

  let root = null;
  let hasCreateWritable = false;
  let worker = null;
  let workerMsgId = 0;
  const pending = new Map();

  async function ensureRoot() {
    if (root) return root;
    if (!navigator.storage || !navigator.storage.getDirectory) {
      throw new Error('OPFS not supported');
    }
    root = await navigator.storage.getDirectory();
    try {
      const probe = await root.getFileHandle('__opfs_write_test__', { create: true });
      hasCreateWritable = 'createWritable' in probe;
      await root.removeEntry('__opfs_write_test__');
    } catch (e) {
      hasCreateWritable = false;
    }
    return root;
  }

  // A dedicated worker is the ONLY place WebKit <= 18 allows
  // createSyncAccessHandle(). Writing there keeps streaming downloads alive
  // on iOS 15-18 instead of failing at the very first chunk.
  function ensureWorker() {
    if (worker) return Promise.resolve();
    if (typeof Worker === 'undefined') {
      return Promise.reject(new Error('Workers not supported'));
    }
    const source = `
      self.onmessage = async (e) => {
        const { id, cmd, filename, data, offset, size } = e.data;
        try {
          const fs = await navigator.storage.getDirectory();
          const handle = await fs.getFileHandle(filename, { create: true });
          const access = await handle.createSyncAccessHandle();
          try {
            if (cmd === 'write') {
              const written = access.write(data, { at: offset });
              if (written !== data.byteLength) throw new Error('Partial write');
              self.postMessage({ id, ok: true, result: written });
            } else if (cmd === 'truncate') {
              access.truncate(size);
              access.flush();
              self.postMessage({ id, ok: true, result: true });
            } else {
              throw new Error('Unknown cmd: ' + cmd);
            }
          } finally {
            access.close();
          }
        } catch (err) {
          self.postMessage({ id, ok: false, error: err.message });
        }
      };
    `;
    worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'application/javascript' })));
    worker.onmessage = (e) => {
      const { id, ok, result, error } = e.data;
      const entry = pending.get(id);
      if (!entry) return;
      pending.delete(id);
      if (ok) entry.resolve(result);
      else entry.reject(new Error(error));
    };
    return Promise.resolve();
  }

  function workerCall(cmd, filename, data, offset, size) {
    return ensureWorker().then(() => new Promise((resolve, reject) => {
      const id = ++workerMsgId;
      pending.set(id, { resolve, reject });
      const transfer = data ? [data.buffer] : [];
      worker.postMessage({ id, cmd, filename, data, offset, size }, transfer);
      setTimeout(() => {
        if (pending.has(id)) {
          pending.delete(id);
          reject(new Error('Worker write timeout'));
        }
      }, 30000);
    }));
  }

  return {
    /**
     * Check if a model is already cached in OPFS
     * @param {string} filename - Model filename (used as cache key)
     * @returns {Promise<boolean>} True if model exists in OPFS
     */
    async isModelCached(filename) {
      try {
        await (await ensureRoot()).getFileHandle(filename);
        return true;
      } catch (error) {
        return false;
      }
    },

    /**
     * Get the size of a cached model
     * @param {string} filename - Model filename
     * @returns {Promise<number|null>} File size in bytes, or null if not found
     */
    async getCachedModelSize(filename) {
      try {
        const handle = await (await ensureRoot()).getFileHandle(filename);
        return (await handle.getFile()).size;
      } catch (error) {
        return null;
      }
    },

    /**
     * Download a model file to OPFS with progress tracking and cancellation.
     *
     * @param {string} url - Model download URL
     * @param {string} filename - Filename to save in OPFS
     * @param {string|null} authToken - Optional auth token (e.g. HuggingFace)
     * @param {function(number): void} onProgress - Progress callback (0-100)
     * @param {AbortSignal|null} abortSignal - Optional AbortSignal for cancellation
     * @returns {Promise<boolean>} True on success
     * @throws {Error} On download failure, storage quota exceeded, or cancellation
     */
    async downloadToOPFS(url, filename, authToken, onProgress, abortSignal) {
      let reader = null;
      let writable = null;
      let closed = false;

      try {
        console.log(`[OPFS] Starting download: ${filename} from ${url}`);

        const estimate = await navigator.storage.estimate();
        console.log(`[OPFS] Storage - Used: ${(estimate.usage / 1e9).toFixed(2)}GB, Quota: ${(estimate.quota / 1e9).toFixed(2)}GB`);

        const fetchOptions = {};
        if (authToken) fetchOptions.headers = { 'Authorization': `Bearer ${authToken}` };
        if (abortSignal) fetchOptions.signal = abortSignal;

        const response = await fetch(url, fetchOptions);
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const contentLength = parseInt(response.headers.get('content-length') || '0');
        console.log(`[OPFS] Content-Length: ${(contentLength / 1e9).toFixed(2)}GB`);

        if (estimate.quota && contentLength > 0) {
          const availableSpace = estimate.quota - (estimate.usage || 0);
          if (contentLength > availableSpace) {
            throw new Error(
              `Insufficient storage: need ${(contentLength / 1e9).toFixed(2)}GB, ` +
              `available ${(availableSpace / 1e9).toFixed(2)}GB`
            );
          }
        }

        const fs = await ensureRoot();
        const fileHandle = await fs.getFileHandle(filename, { create: true });

        let useWorker = false;
        if (hasCreateWritable) {
          writable = await fileHandle.createWritable();
        } else {
          useWorker = true;
          await workerCall('truncate', filename, null, 0, contentLength || 0);
          console.log(`[OPFS] createWritable unavailable - worker sync-access fallback for ${filename}`);
        }

        reader = response.body.getReader();
        let bytesReceived = 0;
        let lastProgressPercent = 0;

        while (true) {
          if (abortSignal && abortSignal.aborted) {
            throw new DOMException('Download aborted', 'AbortError');
          }

          const { done, value } = await reader.read();
          if (done) break;

          if (useWorker) {
            await workerCall('write', filename, value, bytesReceived);
          } else {
            await writable.write(value);
          }
          bytesReceived += value.length;

          if (contentLength > 0) {
            const progressPercent = Math.round((bytesReceived / contentLength) * 100);
            if (progressPercent !== lastProgressPercent) {
              onProgress(progressPercent);
              lastProgressPercent = progressPercent;
            }
          }
        }

        if (!useWorker) {
          await writable.close();
          writable = null;
        }
        closed = true;

        console.log(`[OPFS] Download complete: ${filename} (${(bytesReceived / 1e9).toFixed(2)}GB)`);
        return true;

      } catch (error) {
        if (reader) {
          try { await reader.cancel(); } catch (e) { /* ignore */ }
        }
        if (!useWorker && writable && !closed) {
          try { await writable.abort(); } catch (e) { /* ignore */ }
        }

        if (error.name === 'AbortError') {
          console.log(`[OPFS] Download aborted: ${filename}`);
          try {
            await (await ensureRoot()).removeEntry(filename);
            console.log(`[OPFS] Cleaned up partial file: ${filename}`);
          } catch (e) { /* ignore */ }
        } else {
          console.error(`[OPFS] Download failed: ${error.message}`);
        }

        throw error;
      }
    },

    /**
     * Get a ReadableStreamDefaultReader for a cached model file.
     * Used to pass the model to MediaPipe's modelAssetBuffer parameter.
     *
     * @param {string} filename - Model filename in OPFS
     * @returns {Promise<ReadableStreamDefaultReader>} Stream reader for the file
     * @throws {Error} If file not found in OPFS
     */
    async getStreamReader(filename) {
      try {
        const handle = await (await ensureRoot()).getFileHandle(filename);
        const file = await handle.getFile();
        return file.stream().getReader();
      } catch (error) {
        console.error(`[OPFS] Failed to get stream reader: ${error.message}`);
        throw new Error(`Model not found in OPFS: ${filename}`);
      }
    },

    /**
     * Get a ReadableStream for streaming a cached model (NOT a reader).
     * Used by @litert-lm/core Engine.create({model: <ReadableStream>}) on web.
     *
     * @param {string} filename - Model filename in OPFS
     * @returns {Promise<ReadableStream>} Raw ReadableStream for the file
     * @throws {Error} If file not found in OPFS
     */
    async getReadableStream(filename) {
      try {
        const handle = await (await ensureRoot()).getFileHandle(filename);
        const file = await handle.getFile();
        return file.stream();
      } catch (error) {
        console.error(`[OPFS] Failed to get readable stream: ${error.message}`);
        throw new Error(`Model not found in OPFS: ${filename}`);
      }
    },

    /**
     * Write a small text file (the ".complete" marker) through the same write
     * path as the model download, so Safari/iOS gets the worker shim too.
     *
     * @param {string} filename - Marker filename in OPFS
     * @param {string} text - The text to store
     * @returns {Promise<boolean>} True on success
     */
    async writeMarker(filename, text) {
      const fs = await ensureRoot();
      const handle = await fs.getFileHandle(filename, { create: true });
      if (hasCreateWritable) {
        const writable = await handle.createWritable();
        await writable.write(text);
        await writable.close();
        return true;
      }
      await workerCall('write', filename, new TextEncoder().encode(text), 0);
      return true;
    },

    /**
     * Delete a model from OPFS
     * @param {string} filename - Model filename to delete
     * @returns {Promise<void>}
     */
    async deleteModel(filename) {
      try {
        await (await ensureRoot()).removeEntry(filename);
        console.log(`[OPFS] Deleted: ${filename}`);
      } catch (error) {
        console.error(`[OPFS] Failed to delete ${filename}: ${error.message}`);
        throw error;
      }
    },

    /**
     * Get current storage statistics
     * @returns {Promise<{usage: number, quota: number}>} Storage stats in bytes
     */
    async getStorageStats() {
      const estimate = await navigator.storage.estimate();
      return { usage: estimate.usage || 0, quota: estimate.quota || 0 };
    },

    /**
     * What this browser can actually do with OPFS files. Dart reads this to
     * decide between streaming (OPFS) and the Cache API, and to explain a
     * failure instead of blaming the connection.
     *
     * @returns {Promise<{createWritable: boolean, syncAccessHandle: boolean, workerAvailable: boolean}>}
     */
    async getWriteCapabilities() {
      await ensureRoot();
      let syncAccessHandle = false;
      try {
        syncAccessHandle = 'createSyncAccessHandle' in FileSystemFileHandle.prototype;
      } catch (e) { /* ignore */ }
      return {
        createWritable: hasCreateWritable,
        syncAccessHandle: syncAccessHandle,
        workerAvailable: typeof Worker !== 'undefined'
      };
    },

    /**
     * Clear all models from OPFS (for development/testing)
     * @returns {Promise<number>} Number of files deleted
     */
    async clearAll() {
      try {
        const fs = await ensureRoot();
        let count = 0;
        for await (const [name, handle] of fs.entries()) {
          if (handle.kind === 'file') {
            await fs.removeEntry(name);
            count++;
          }
        }
        console.log(`[OPFS] Cleared ${count} files`);
        return count;
      } catch (error) {
        console.error(`[OPFS] Failed to clear: ${error.message}`);
        throw error;
      }
    }
  };
})();

// Log OPFS availability and write capability on load
if (typeof navigator !== 'undefined' && navigator.storage && navigator.storage.getDirectory) {
  navigator.storage.getDirectory().then((fs) => {
    return fs.getFileHandle('__opfs_write_test__', { create: true });
  }).then((handle) => {
    const ok = 'createWritable' in handle;
    return navigator.storage.getDirectory().then((fs) => {
      return fs.removeEntry('__opfs_write_test__');
    }).then(() => {
      console.log(`[OPFS] Origin Private File System available (createWritable: ${ok})`);
    });
  }).catch(() => {
    console.warn('[OPFS] Origin Private File System NOT available - streaming mode will not work');
  });
} else {
  console.warn('[OPFS] Origin Private File System NOT available - streaming mode will not work');
}