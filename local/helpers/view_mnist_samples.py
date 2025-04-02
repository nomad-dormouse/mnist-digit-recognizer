#!/usr/bin/env python3
"""
================================================================================
MNIST DATASET VISUALIZATION TOOL
================================================================================
This script visualizes a random selection of MNIST handwritten digit samples
in a 5x5 grid using Plotly and saves the result as an interactive HTML file.

Purpose:
    - View actual MNIST dataset examples to understand the training data
    - Generate sample digit images for testing or documentation
    - See the variety of handwriting styles in the dataset

Usage:
    ./local/helpers/view_mnist_samples.py

Requirements:
    - PyTorch and torchvision (for loading the MNIST dataset)
    - Plotly (for creating the visualization)
    - Internet connection (first run only, to download the dataset)

Output:
    - Interactive HTML file with a 5x5 grid of MNIST digit images
    - The file will open automatically in your default web browser
    - Each run generates a new random selection of images
================================================================================
"""
import os
import webbrowser
import numpy as np
import torch
import torchvision
import plotly.graph_objects as go
import plotly.subplots as sp

# CONFIGURATION
# File settings
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "mnist_samples.html")
GRID_SIZE = 5  # 5x5 grid

# DATA LOADING
# Load MNIST dataset
print("Loading MNIST dataset...")
mnist_train = torchvision.datasets.MNIST(
    root='./data', 
    train=True, 
    download=True, 
    transform=torchvision.transforms.ToTensor()
)

# VISUALIZATION CREATION
# Create plot
fig = sp.make_subplots(rows=GRID_SIZE, cols=GRID_SIZE)

# Generate a 5x5 grid of random MNIST images
digit_labels = []
for i in range(GRID_SIZE):
    for j in range(GRID_SIZE):
        # Get random image
        idx = np.random.randint(len(mnist_train))
        img, label = mnist_train[idx]
        digit_labels.append(label)
        
        # Add image to subplot
        fig.add_trace(
            go.Heatmap(
                z=img.numpy()[0],
                colorscale='gray_r',
                showscale=False,
                hoverinfo='none',
                zmin=0, zmax=1
            ),
            row=i+1, col=j+1
        )

# Update layout
fig.update_layout(
    title_text="MNIST Dataset Sample Images",
    height=800, width=1000,
    showlegend=False,
)

# Update axes
for i in range(GRID_SIZE * GRID_SIZE):
    row, col = i//GRID_SIZE+1, i%GRID_SIZE+1
    fig.update_xaxes(showticklabels=False, showgrid=False, zeroline=False, row=row, col=col)
    fig.update_yaxes(showticklabels=False, showgrid=False, zeroline=False, row=row, col=col)
    
    # Add digit label
    fig.update_layout(**{
        f'xaxis{i+1}_title': f'Label: {digit_labels[i]}',
        f'xaxis{i+1}_title_font': {'size': 16, 'color': 'blue'},
    })

# OUTPUT AND DISPLAY
# Save and display
fig.write_html(OUTPUT_FILE)
file_path = os.path.abspath(OUTPUT_FILE)

# Open in browser
print(f"Opening {OUTPUT_FILE} in your default browser...")
webbrowser.open('file://' + file_path)

# USER INFORMATION
# Summary info
print(f"\nMNIST Dataset Information:")
print(f"- Training samples: {len(mnist_train)}")
print(f"- Image dimensions: 28x28 pixels (grayscale)")
print(f"- Labels: Digits 0-9")
print(f"- Visualization saved to: {OUTPUT_FILE}") 