import unittest
import time
import pytest
from exampleproject.main import combine_words, print_delayed

def test_combine_words():
    assert (combine_words("hello", "world") == "hello world")

@pytest.mark.timeout(2)
def test_slow_operation():
    print_delayed("hello world", 1)
