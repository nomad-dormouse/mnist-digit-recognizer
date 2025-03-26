#!/usr/bin/env python3
import torch
import torchvision
import plotly.graph_objects as go
import plotly.subplots as sp
import numpy as np
import webbrowser
import os
from torchvision import datasets, transforms

# Load MNIST dataset without normalization for visualization
mnist_train = datasets.MNIST(root='./data', train=True, download=True, transform=transforms.ToTensor())

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
        
        # Convert tensor to numpy array (no denormalization needed since we didn't normalize)
        img_array = img.numpy()[0]
        
        # Add image to subplot
        fig.add_trace(
            go.Heatmap(
                z=img_array,
                colorscale='gray_r',  # Reversed grayscale for proper display (white=0, black=1)
                showscale=False,
                hoverinfo='none',
                zmin=0,
                zmax=1
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

# File path
output_file = "mnist_samples_plotly.html"

# Show the figure
fig.write_html(output_file)

# Get the absolute file path
file_path = os.path.abspath(output_file)

# Open the HTML file in the default web browser
print(f"Opening {output_file} in your default browser...")
webbrowser.open('file://' + file_path)

print("MNIST dataset visualization complete!")
print("A random sample of 25 images has been displayed with Plotly.")
print(f"The visualization has been saved to '{output_file}'")

# Display dataset statistics
print("\nMNIST Dataset Information:")
print(f"Total training samples: {len(mnist_train)}")
print("Image dimensions: 28x28 pixels (grayscale)")
print("Labels: Digits from 0 to 9")
print("Each pixel value ranges from 0 (white) to 1 (black)") 