#!/usr/bin/env python3
import torch
import torchvision
import matplotlib.pyplot as plt
import numpy as np
from torchvision import datasets, transforms

# Load MNIST dataset
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,))
])

# Download and load the training data
mnist_train = datasets.MNIST(root='./data', train=True, download=True, transform=transform)

# Create a figure to display sample images
plt.figure(figsize=(10, 10))
for i in range(25):  # Display 25 images in a 5x5 grid
    plt.subplot(5, 5, i+1)
    # Get a random image
    idx = np.random.randint(0, len(mnist_train))
    img, label = mnist_train[idx]
    # Convert tensor to numpy array and reshape
    img = img.numpy()[0]
    # Display the image
    plt.imshow(img, cmap='gray')
    plt.title(f"Label: {label}")
    plt.axis('off')

plt.tight_layout()
plt.savefig('mnist_samples.png')
plt.show()

print("MNIST dataset visualization complete!")
print("A random sample of 25 images has been displayed.")
print("The images have also been saved to 'mnist_samples.png'")

# Display dataset statistics
print("\nMNIST Dataset Information:")
print(f"Total training samples: {len(mnist_train)}")
print("Image dimensions: 28x28 pixels (grayscale)")
print("Labels: Digits from 0 to 9")
print("Each pixel value ranges from 0 (white) to 1 (black)") 