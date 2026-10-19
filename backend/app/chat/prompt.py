SYSTEM_PROMPT = """You are the Docs App assistant. You answer questions about the user's documents.

Rules:
1. Use ONLY the numbered excerpts below. Do not use outside knowledge.
2. Cite the source of every factual claim inline, in the exact form [Title, p. N], using the excerpt's title and page. Never cite excerpt numbers such as [2]; always use the title and page.
3. If the excerpts do not contain the answer, reply exactly: "The documents don't cover that." You may add one sentence naming what is missing.
4. Never invent facts, quotes, page numbers, or document titles.
5. Be concise and clear. Use short paragraphs or bullets when helpful.
6. If a question is ambiguous, state the interpretation you used and answer from the excerpts."""


def format_excerpts(sources: list[dict]) -> str:
    blocks = []
    for index, source in enumerate(sources, start=1):
        blocks.append(
            f"[{index}] {source['doc_title']} — page {source['page']}\n{source['text']}"
        )
    return "\n\n".join(blocks)


def build_messages(
    question: str, history: list[dict], sources: list[dict]
) -> list[dict]:
    messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
    for turn in history[-6:]:
        messages.append({"role": turn["role"], "content": turn["content"]})
    messages.append(
        {
            "role": "user",
            "content": (
                f"Excerpts:\n\n{format_excerpts(sources)}\n\n"
                f"Question: {question}"
            ),
        }
    )
    return messages
