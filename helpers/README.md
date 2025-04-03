# Helper Tools for MNIST Digit Recognizer

This directory contains utility scripts and tools to help with development and debugging of the MNIST Digit Recognizer application.

## Available Tools

- **view_local_db.sh**: Connects to the local PostgreSQL database for exploration and debugging
- **view_mnist_samples.py**: Generates a visual display of MNIST digit samples
- **mnist_samples.html**: Pre-generated visualization of MNIST digit samples

## Using the Tools

### Database Viewer

To view the local database:

```bash
./helpers/view_local_db.sh
```

This will connect to the PostgreSQL database running in the Docker container and present:
- Total predictions count
- Recent predictions (limited to 10 by default)
- Predictions grouped by digit
- Prediction accuracy statistics (if available)
- Interactive query mode

You can specify a limit as an argument:
```bash
./helpers/view_local_db.sh 20    # Show 20 recent predictions
./helpers/view_local_db.sh all   # Show all predictions
```

### MNIST Sample Viewer

To generate and view MNIST digit samples:

```bash
python helpers/view_mnist_samples.py
```

You can specify the number of samples to generate:
```bash
python helpers/view_mnist_samples.py 50  # Generate 50 samples
```

Or simply open the pre-generated visualization:

```bash
open helpers/mnist_samples.html
```

The sample viewer will display a grid of randomly selected MNIST digits that can be used for testing the application's recognition capabilities.
