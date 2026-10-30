def greet(name):
    """Say hello."""
    print("Hello, " + name)


def add(a, b):
    return a + b


for i in range(3):
    greet("world %d" % i)
