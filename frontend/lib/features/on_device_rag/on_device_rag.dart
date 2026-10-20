/// On-device RAG: PDFs, embeddings, the vector index and retrieval all stay
/// in the browser. The backend only extracts text and proxies the cloud
/// model over excerpts this pipeline retrieved.
library;

export 'document_catalog.dart';
export 'document_ingest.dart';
export 'local_index.dart';
export 'local_library.dart';
export 'local_retriever.dart';
export 'on_device_rag_startup.dart';
export 'pdf_blob_store.dart';
export 'rag_chunk.dart';
export 'search_model_store.dart';
export 'sequential_model_loader.dart';
