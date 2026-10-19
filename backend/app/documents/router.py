from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, File, HTTPException, UploadFile
from fastapi.responses import Response

from app.clients import get_qdrant, get_settings
from app.documents import repo
from app.documents.schemas import DocumentOut
from app.ingest.files_repo import load_file
from app.ingest.job import ingest_document

router = APIRouter(prefix="/documents", tags=["documents"])


def _title_from(filename: str) -> str:
    base = (filename or "Untitled").rsplit(".", 1)[0]
    return base.replace("_", " ").replace("-", " ").strip() or "Untitled"


@router.post("", response_model=DocumentOut)
async def upload_document(
    background_tasks: BackgroundTasks, file: UploadFile = File(...)
) -> DocumentOut:
    settings = get_settings()
    data = await file.read()
    if not data.startswith(b"%PDF"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported.")
    limit = settings.max_upload_mb * 1024 * 1024
    if len(data) > limit:
        raise HTTPException(
            status_code=413,
            detail=f"File is too large. The limit is {settings.max_upload_mb} MB.",
        )

    doc_id = str(uuid4())
    payload = {
        "id": doc_id,
        "title": _title_from(file.filename or ""),
        "filename": file.filename or "document.pdf",
        "pages": 0,
        "size_bytes": len(data),
        "uploaded_at": datetime.now(timezone.utc).isoformat(),
        "status": "processing",
        "chunks": 0,
        "error": None,
    }
    repo.save_meta(get_qdrant(), settings, doc_id, payload)
    background_tasks.add_task(ingest_document, doc_id, data, payload["title"], settings)
    return DocumentOut(**payload)


@router.get("", response_model=list[DocumentOut])
def list_documents() -> list[DocumentOut]:
    return [DocumentOut(**item) for item in repo.list_meta(get_qdrant(), get_settings())]


@router.get("/{doc_id}/status", response_model=DocumentOut)
def document_status(doc_id: str) -> DocumentOut:
    payload = repo.get_meta(get_qdrant(), get_settings(), doc_id)
    if not payload:
        raise HTTPException(status_code=404, detail="Document not found.")
    return DocumentOut(**payload)


@router.get("/{doc_id}/file")
def document_file(doc_id: str) -> Response:
    settings = get_settings()
    payload = repo.get_meta(get_qdrant(), settings, doc_id)
    if not payload:
        raise HTTPException(status_code=404, detail="Document not found.")
    data = load_file(get_qdrant(), settings, doc_id)
    if not data:
        raise HTTPException(status_code=409, detail="File is still processing.")
    return Response(
        content=data,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{payload.get("filename")}"'
        },
    )


@router.delete("/{doc_id}")
def delete_document(doc_id: str) -> dict:
    settings = get_settings()
    if not repo.get_meta(get_qdrant(), settings, doc_id):
        raise HTTPException(status_code=404, detail="Document not found.")
    repo.delete_document(get_qdrant(), settings, doc_id)
    return {"deleted": doc_id}
