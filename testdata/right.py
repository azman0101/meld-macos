def greet(name: str) -> None:
    """Say hello politely."""
    print(f"Hello, {name}!")


def add(a, b):
    return a + b


def sub(a, b):
    return a - b


for i in range(5):
    greet(f"world {i}")
