import time
import logging

logger = logging.getLogger(__name__)

def combine_words(word_1: str, word_2: str) -> str:
    return f"{word_1} {word_2}"

def print_delayed(message: str, delay_s: int = 0) -> None:
    logger.debug("entered print_delay")
    assert delay_s >= 0, f"Delay {delay_s} must be positive!"
    time.sleep(delay_s)
    print(message)

def configure_logging(level=logging.DEBUG):
    logger.setLevel(level)
    stream_handler = logging.StreamHandler()
    stream_handler.setLevel(level)

    formatter = logging.Formatter('%(levelname)s:%(name)s: %(message)s')
    stream_handler.setFormatter(formatter)

    logger.addHandler(stream_handler)

def main() -> None:
    configure_logging()
    hello_world = combine_words("hello", "world")
    print_delayed(hello_world, 1)

if __name__ == "__main__":
    main()