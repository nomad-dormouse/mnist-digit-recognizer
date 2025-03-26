#!/usr/bin/env python3
import torch
import torchvision
import plotly.graph_objects as go
import plotly.subplots as sp
import numpy as np
from torchvision import datasets, transforms

# Load MNIST dataset
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,))
])

# Download and load the training data
mnist_train = datasets.MNIST(root='./data', train=True, download=True, transform=transform)

# Create a figure to display sample images with Plotly
fig = sp.make_subplots(rows=5, cols=5, 
                      subplot_titles=[f"" for _ in range(25)])

# Create a 5x5 grid of images
digit_labels = []  # Store labels for the title
for i in range(5):
    for j in range(5):
        # Get a random image
        idx = np.random.randint(0, len(mnist_train))
        img, label = mnist_train[idx]
        digit_labels.append(label)
        
        # Convert tensor to numpy array
        img_array = img.numpy()[0]
        
        # Add image to subplot
        fig.add_trace(
            go.Heatmap(
                z=img_array,
                colorscale='gray',
                showscale=False,
                hoverinfo='none'
            ),
            row=i+1, col=j+1
        )

# Update the layout and axes
fig.update_layout(
    title_text="MNIST Dataset Sample Images",
    height=800,
    width=1000,
    showlegend=False,
)

# Update axes to remove ticks and labels but add clear digit labels
for i in range(25):
    fig.update_xaxes(showticklabels=False, showgrid=False, zeroline=False, row=i//5+1, col=i%5+1)
    fig.update_yaxes(showticklabels=False, showgrid=False, zeroline=False, row=i//5+1, col=i%5+1)
    
    # Add clearly visible title for each subplot
    fig.update_layout(**{
        f'xaxis{i+1}_title': f'Label: {digit_labels[i]}',
        f'xaxis{i+1}_title_font': {'size': 16, 'color': 'blue'},
    })

# Show the figure
fig.write_html("mnist_samples_plotly.html")
fig.show()

print("MNIST dataset visualization complete!")
print("A random sample of 25 images has been displayed with Plotly.")
print("The visualization has been saved to 'mnist_samples_plotly.html'")

# Display dataset statistics
print("\nMNIST Dataset Information:")
print(f"Total training samples: {len(mnist_train)}")
print("Image dimensions: 28x28 pixels (grayscale)")
print("Labels: Digits from 0 to 9")
print("Each pixel value ranges from 0 (white) to 1 (black)") 