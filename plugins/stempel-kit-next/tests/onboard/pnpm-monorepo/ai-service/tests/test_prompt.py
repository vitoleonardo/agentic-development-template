import pytest

from assist.prompt import build_prompt


def test_build_prompt_lists_context() -> None:
    assert build_prompt("Why?", ["a", "b"]) == "Context:\n- a\n- b\n\nQuestion: Why?"


def test_build_prompt_rejects_empty_question() -> None:
    with pytest.raises(ValueError):
        build_prompt("  ", [])
