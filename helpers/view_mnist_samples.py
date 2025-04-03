#!/usr/bin/env python3
"""MNIST dataset visualization tool - Shows random samples in a 5x5 grid"""
import os
import sys
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import base64
from io import BytesIO

# Get the current script location
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent

# Import the model module from the project root
sys.path.append(str(PROJECT_ROOT))
try:
    from model.model import load_mnist_data
except ImportError:
    print("Error: Could not import load_mnist_data from model module.")
    print("Make sure the model module is in the correct location.")
    sys.exit(1)

def generate_samples_html(num_samples=100, output_file=None):
    """Generate HTML with MNIST samples."""
    print("Loading MNIST data...")
    
    # Try to load the data
    try:
        train_X, train_y, test_X, test_y = load_mnist_data()
    except Exception as e:
        print(f"Error loading MNIST data: {e}")
        return
    
    # Select random samples from the test set
    indices = np.random.choice(len(test_X), min(num_samples, len(test_X)), replace=False)
    samples_X = test_X[indices]
    samples_y = test_y[indices]

    # Set up the figure
    print(f"Generating {len(indices)} sample images...")
    num_cols = 10
    num_rows = (len(indices) + num_cols - 1) // num_cols
    
    plt.figure(figsize=(2*num_cols, 2*num_rows))
    
    # Generate base64 encoded images for inline HTML
    images_html = []
    
    # Create a grid of images
    for i, (img, label) in enumerate(zip(samples_X, samples_y)):
        # Create a new figure for each image
        fig = plt.figure(figsize=(2, 2))
        plt.imshow(img.reshape(28, 28), cmap='gray')
        plt.title(f"Digit: {label}")
        plt.axis('off')
        
        # Save image to a BytesIO object
        buf = BytesIO()
        plt.savefig(buf, format='png', bbox_inches='tight', pad_inches=0.1)
        buf.seek(0)
        
        # Encode the image as base64
        img_base64 = base64.b64encode(buf.read()).decode('utf-8')
        images_html.append(f'<div class="digit-container">\n'
                          f'  <img src="data:image/png;base64,{img_base64}" alt="Digit {label}">\n'
                          f'  <p>Digit: {label}</p>\n'
                          f'</div>')
        
        plt.close(fig)
    
    # Create the HTML file
    html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>MNIST Digit Samples</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }}
        h1 {{
            color: #333;
            text-align: center;
        }}
        .samples-container {{
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
        }}
        .digit-container {{
            margin: 10px;
            text-align: center;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 10px;
            width: 100px;
        }}
        .digit-container img {{
            width: 100%;
            height: auto;
        }}
        .digit-container p {{
            margin: 5px 0 0 0;
            font-weight: bold;
        }}
        .info {{
            margin: 20px 0;
            padding: 15px;
            background-color: #f8f9fa;
            border-radius: 5px;
            line-height: 1.5;
        }}
    </style>
</head>
<body>
    <h1>MNIST Digit Samples</h1>
    
    <div class="info">
        <p>This page displays random samples from the MNIST dataset. These images can be used for testing the digit recognition application.</p>
        <p>The MNIST dataset contains 28x28 pixel grayscale images of handwritten digits (0-9).</p>
        <p>To try these samples in the application, you can either:
            <ul>
                <li>Take a screenshot of a digit and upload it</li>
                <li>Draw a similar digit in the application's drawing tool</li>
            </ul>
        </p>
    </div>
    
    <div class="samples-container">
        {"".join(images_html)}
    </div>
</body>
</html>
"""
    
    # Determine output file path
    if output_file is None:
        output_file = SCRIPT_DIR / "mnist_samples.html"
    else:
        output_file = Path(output_file)
    
    # Write the HTML file
    with open(output_file, 'w') as f:
        f.write(html_content)
    
    print(f"Generated samples HTML file: {output_file}")
    print("You can open this file in a web browser to view the samples.")

if __name__ == "__main__":
    # Parse command line arguments
    num_samples = 100
    if len(sys.argv) > 1:
        try:
            num_samples = int(sys.argv[1])
        except ValueError:
            print(f"Error: Invalid number of samples: {sys.argv[1]}")
            print("Using default value of 100 samples.")
    
    output_file = None
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    
    generate_samples_html(num_samples, output_file) 