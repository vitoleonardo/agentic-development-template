"""Prompt building."""


def build_prompt(question: str, context: list[str]) -> str:
    """Join the context and the question into one prompt."""
    if not question.strip():
        raise ValueError("question must not be empty")
    lines = [f"- {item}" for item in context]
    return "Context:\n" + "\n".join(lines) + f"\n\nQuestion: {question.strip()}"
