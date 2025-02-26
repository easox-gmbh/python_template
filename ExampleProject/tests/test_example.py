"""Example pytest"""

import pytest

from exampleproject.main import combine_words, print_delayed


def test_combine_words() -> None:
    assert combine_words("hello", "world") == "hello world"


@pytest.mark.timeout(2)  # type: ignore[misc]
def test_slow_operation() -> None:
    print_delayed("hello world", 1)
