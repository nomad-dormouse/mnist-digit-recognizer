# MNIST Digit Recognizer

A full-stack machine learning application that allows users to draw digits and get real-time predictions using a PyTorch model trained on the MNIST dataset.

**Live Demo**: [http://37.27.197.79:8501](http://37.27.197.79:8501)

**GitHub Repository**: [https://github.com/nomad-dormouse/mnist-digit-recognizer](https://github.com/nomad-dormouse/mnist-digit-recognizer)

## Features

- Deep learning model for handwritten digit classification (PyTorch)
- Interactive web interface with drawing canvas (Streamlit)
- Database for prediction logging and analytics (PostgreSQL)
- Containerized deployment with Docker and Docker Compose
- Automated deployment pipeline

## Project Overview

This project demonstrates an end-to-end machine learning application that:

1. Implements a PyTorch Convolutional Neural Network (CNN) trained on the MNIST dataset
2. Provides an intuitive web interface for drawing digits and receiving real-time predictions
3. Records predictions and user feedback in a PostgreSQL database for continuous improvement
4. Deploys seamlessly using containerization for consistent environments

## Project Structure

```
project_root/
├── app.py             # Main application code
├── init.sql           # Database initialization script
├── Dockerfile         # Multi-stage Dockerfile for all environments
├── docker-compose.yml # Base Docker Compose configuration
├── .env               # Environment variables (consolidated)
├── model/             # Model training and inference
│   ├── model.py       # Model definition
│   ├── train.py       # Model training script
│   ├── data/          # MNIST dataset storage
│   └── saved_models/  # Trained model weights
├── local/             # Local development setup
│   ├── deploy_locally.sh    # Local development script
│   ├── view_local_db.sh     # View local database records
│   ├── view_mnist_samples.py # View MNIST dataset samples
│   └── mnist_samples.html   # Pre-generated HTML with MNIST samples
└── remote/            # Remote deployment components
    ├── deploy.sh      # Main deployment script
    ├── docker-compose.remote.override.yml  # Remote Docker Compose overrides
    ├── common.sh      # Common functions
    ├── database.sh    # Database management
    ├── services.sh    # Service management
    └── helpers/       # Helper scripts for monitoring
        ├── check_web_logs.sh
        └── view_db.sh
```

## Local Development

For detailed instructions on setting up and running the application locally, please refer to the [Local Development Guide](local/README.md).

This includes:
- Quick setup with Docker
- Manual setup instructions
- Database initialization and management
- Environment configuration
- Development tools and utilities

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/nomad-dormouse/mnist-digit-recognizer.git
   cd mnist-digit-recognizer
   ```

2. Configure your environment by editing the `.env` file if needed.

3. Run the local development script:
   ```bash
   ./local/deploy_locally.sh
   ```

The application will be available at `http://localhost:8501`

## Deployment

To deploy the application to a production server:

1. **Prepare the server:**
   - Install Docker and Docker Compose
   - Set up SSH access with your key
   - Create the deployment directory

2. **Configure deployment:**
   Update the deployment configuration in `.env`:
   - Set your server IP in `REMOTE_HOST`
   - Configure SSH key path in `SSH_KEY`
   - Set database credentials if needed
   - Adjust other deployment settings as needed

3. **Run the deployment script:**
   ```bash
   ./remote/deploy.sh
   ```

4. **Verify deployment:**
   - Check application logs: `./remote/helpers/check_web_logs.sh`
   - View database status: `./remote/helpers/view_db.sh`
   - Access the application at `http://your-server-ip:8501`

### Database Management

The application uses PostgreSQL for storing predictions. The database is:
- Automatically initialized during first deployment
- Backed up regularly (configurable interval)
- Monitored for health and connectivity
- Protected with proper access controls

For database management commands, see the [Remote Helpers Guide](remote/helpers/README.md).

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
- Environment variables are loaded in both development and production
- The application adapts its behavior based on the environment it's running in
- Docker Compose loads variables from the same file for consistent configuration

### Docker Configuration

The project uses a multi-stage Dockerfile approach for better maintainability:
- A single `Dockerfile` in the root directory contains stages for both local and remote environments
- The `base` stage contains common dependencies and configuration
- The `local` stage adds development-specific settings
- The `remote` stage adds production-specific settings
- Docker Compose override files specify which target to use for each environment

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
