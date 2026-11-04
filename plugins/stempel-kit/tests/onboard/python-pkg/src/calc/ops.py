"""Operations on integer amounts in cents."""


def add(a: int, b: int) -> int:
    return a + b


def split(total: int, parts: int) -> list[int]:
    """Split total into parts that differ by at most one cent."""
    if parts <= 0:
        raise ValueError("parts must be positive")
    base, rest = divmod(total, parts)
    return [base + 1 if i < rest else base for i in range(parts)]
