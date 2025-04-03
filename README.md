# MNIST Digit Recognizer

A full-stack machine learning application that allows users to draw digits and get real-time predictions using a PyTorch model trained on the MNIST dataset.

**Live Demo**: [http://37.27.197.79:8501](http://37.27.197.79:8501)

**GitHub Repository**: [https://github.com/nomad-dormouse/mnist-digit-recognizer](https://github.com/nomad-dormouse/mnist-digit-recognizer)

## Features

- Deep learning model for handwritten digit classification (PyTorch)
- Interactive web interface with drawing canvas (Streamlit)
- Database for prediction logging and analytics (PostgreSQL)
- Containerized deployment with Docker and Docker Compose
- Automated deployment pipeline for both local and remote environments

## Project Overview

This project demonstrates an end-to-end machine learning application that:

1. Implements a PyTorch Convolutional Neural Network (CNN) trained on the MNIST dataset
2. Provides an intuitive web interface for drawing digits and receiving real-time predictions
3. Records predictions and user feedback in a PostgreSQL database for continuous improvement
4. Deploys seamlessly using containerization for consistent environments

## Project Structure

```
project_root/
├── app.py                # Main application code
├── deploy.sh             # Main deployment script for both local and remote
├── deploy_remotely.sh    # Script for deploying to remote server
├── init.sql              # Database initialization script
├── Dockerfile            # Multi-stage Dockerfile for all environments
├── docker-compose.yml    # Docker Compose configuration
├── .env                  # Environment variables (consolidated)
├── model/                # Model training and inference
│   ├── model.py          # Model definition
│   ├── train.py          # Model training script
│   ├── data/             # MNIST dataset storage
│   └── saved_models/     # Trained model weights
└── helpers/              # Helper utilities and tools
    ├── view_local_db.sh       # View local database records
    ├── view_mnist_samples.py  # View MNIST dataset samples
    └── mnist_samples.html     # Pre-generated HTML with MNIST samples
```

## Local Development

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/nomad-dormouse/mnist-digit-recognizer.git
   cd mnist-digit-recognizer
   ```

2. Configure your environment by editing the `.env` file if needed.

3. Run the local deployment script:
   ```bash
   ./deploy.sh local up
   ```

The application will be available at `http://localhost:8501`

### Helper Tools

For development and debugging, several helper tools are available in the `helpers` directory:

- **Database Viewer**: `./helpers/view_local_db.sh` - Connects to the local PostgreSQL database
- **MNIST Samples Viewer**: `./helpers/view_mnist_samples.py` - Generates visualizations of MNIST digits

For detailed instructions on using these tools, refer to the [Helpers README](helpers/README.md).

## Deployment

The application can be deployed in both local and remote environments using the same deployment scripts.

### Local Deployment

```bash
./deploy.sh local [action]
```

Actions include:
- `up` - Start the application (default)
- `down` - Stop the application
- `restart` - Restart the application
- `logs` - View application logs
- `status` - Check application status

### Remote Deployment

To deploy to a remote production server:

1. **Configure remote settings in `.env`**:
   - Set your server IP in `REMOTE_HOST`
   - Configure SSH key path in `SSH_KEY` 
   - Set remote user in `REMOTE_USER`
   - Set remote directory in `REMOTE_DIR`

2. **Deploy using the remote deployment script**:
   ```bash
   ./deploy_remotely.sh
   ```

3. **Manage remote deployment**:
   ```bash
   ./deploy_remotely.sh status    # Check status
   ./deploy_remotely.sh down      # Stop application
   ./deploy_remotely.sh restart   # Restart application
   ```

### Database Management

The application stores predictions in a PostgreSQL database, which persists between container restarts.

Key features:
- Prediction history is displayed in the web interface
- Historical data can be queried using the database viewer tool
- Database is automatically backed up periodically

## Technical Details

### Model Architecture

The digit recognition model is a Convolutional Neural Network (CNN) with:
- 2 convolutional layers with ReLU activation
- Max pooling layers for spatial dimensionality reduction
- Dropout regularization to prevent overfitting
- 2 fully connected layers for classification
- Trained to >99% accuracy on the MNIST dataset

### Environment Configuration

The project uses a consolidated approach to environment variables:
- A single `.env` file in the root directory contains all configuration for both local and remote environments
- Environment variables are loaded by all scripts and containers
- The application adapts its behavior based on the environment it's running in
- Docker Compose loads variables from the same file for consistent configuration

### Docker Configuration

The project uses a simple but effective Docker approach:
- A single `Dockerfile` for the application
- A single `docker-compose.yml` file for container orchestration
- Environment variables control application behavior for different deployments

### Database Schema

The PostgreSQL database stores predictions with:
- `id`: Auto-incrementing primary key
- `timestamp`: When the prediction was made
- `predicted_digit`: Model's prediction (0-9)
- `true_label`: User-provided correct label (for feedback)
- `confidence`: Model's confidence score (probability)

## AI Development Acknowledgment

This project was developed with assistance from AI tools:
- [Cursor](https://cursor.sh/) - An AI-powered code editor that provided intelligent code suggestions
- The development process involved AI-assisted coding, debugging, and documentation generation, with human oversight for all critical decisions

## License

[MIT License](LICENSE) 
