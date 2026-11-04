import pytest

from calc.ops import add, split


def test_add() -> None:
    assert add(2, 3) == 5


def test_split_uneven() -> None:
    assert split(1000, 3) == [334, 333, 333]


def test_split_rejects_zero_parts() -> None:
    with pytest.raises(ValueError):
        split(10, 0)
