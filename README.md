# MNIST Digit Recognizer

A full-stack machine learning application that allows users to draw digits and get real-time predictions using a PyTorch model trained on the MNIST dataset.

**Live Demo**: [http://37.27.197.79:8501](http://37.27.197.79:8501)

**GitHub Repository**: [https://github.com/nomad-dormouse/mnist-digit-recognizer](https://github.com/nomad-dormouse/mnist-digit-recognizer)

## AI Development Acknowledgment

This project was developed with the assistance of AI tools, specifically:
- [Cursor](https://cursor.sh/) - An AI-powered code editor that provided intelligent code suggestions and pair programming capabilities
- The development process involved AI-assisted coding, debugging, and documentation generation, while maintaining human oversight and validation for all critical decisions and implementations

## Features

- Deep learning model for handwritten digit classification (PyTorch)
- Interactive web interface with drawing canvas (Streamlit)
- Database for prediction logging (PostgreSQL)
- Containerized deployment (Docker & Docker Compose)
- Complete CI/CD pipeline

## Project Overview

This project is an end-to-end machine learning application that:

1. Uses a PyTorch Convolutional Neural Network (CNN) trained on the MNIST dataset
2. Provides a web interface for drawing digits and getting predictions
3. Records predictions and user feedback in a PostgreSQL database
4. Is containerized for easy deployment

## Project Structure

```
.
├── app/                    # Streamlit web application
├── model/                  # PyTorch model and training code
├── database/               # Database schemas and migrations
├── docker/                 # Docker configuration files
├── saved_models/           # Saved model weights
├── deploy.sh               # Deployment script
├── requirements.txt        # Python dependencies
├── docker-compose.yml      # Multi-container Docker setup
└── .env.production         # Production environment variables
```

## Local Development Setup

1. **Create a virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: .\venv\Scripts\activate
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Set up environment variables:**
   Create a `.env` file with the following variables:
   ```
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=mnist_db
   DB_USER=postgres
   DB_PASSWORD=your_password
   ```

4. **Train the model:**
   ```bash
   python model/train.py
   ```

5. **Run the Streamlit app:**
   ```bash
   streamlit run app/app.py
   ```

## Running with Docker

1. **Build and start the containers:**
   ```bash
   docker-compose up
   ```

2. **Access the application:**
   Open your browser and navigate to `http://localhost:8501`

## Deployment

1. **Update the deployment script with your server information:**
   Edit `deploy.sh` and update:
   - `REMOTE_HOST` with your server IP
   - `REPO_URL` with your GitHub repository URL

2. **Run the deployment script:**
   ```bash
   ./deploy.sh
   ```
3. **Access the deployed application:**
   Open your browser and navigate to `http://your-server-ip:8501`

## Model Architecture

The model is a Convolutional Neural Network (CNN) with the following architecture:
- 2 convolutional layers with ReLU activation
- Max pooling
- Dropout for regularization
- 2 fully connected layers
- Trained to >99% accuracy on the MNIST dataset

## Database Schema

The PostgreSQL database logs predictions with the following schema:
- `id`: Auto-incrementing primary key
- `timestamp`: Timestamp of prediction
- `predicted_digit`: Model's prediction (0-9)
- `true_label`: User-provided correct label
- `confidence`: Model's confidence score

## License

[MIT License](LICENSE) 
