# MNIST Digit Recogniser

A full-stack machine learning application that allows users to draw digits and get real-time predictions using a PyTorch model trained on the MNIST dataset.

**Live Demo**: [http://37.27.197.79:8501](http://37.27.197.79:8501)

**GitHub Repository**: [https://github.com/nomad-dormouse/mnist-digit-recogniser](https://github.com/nomad-dormouse/mnist-digit-recogniser)

## Features

- Draw digits and get instant predictions
- View prediction history and provide feedback
- Containerized deployment with Docker
- PostgreSQL database for analytics

## Quick Start

### Local Deployment

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd mnist-digit-recogniser
   ```

2. Create `.env` file:
   ```bash
   cp .env.template .env
   ```

3. Deploy locally:
   ```bash
   ./deploy.sh
   ```

4. Access at `http://localhost:8501`

### Remote Deployment

1. Deploy to remote server:
   ```bash
   ./deploy_remotely.sh
   ```

2. Access at `http://your-server-ip:8501`

## Project Structure

```
project_root/
├── database/                # Database files
├── model/                   # ML model files
├── webapp/                  # Web application
├── docker-compose.yml      # Docker configuration
├── deploy.sh               # Local deployment
└── deploy_remotely.sh      # Remote deployment
```

## License

[MIT License](LICENSE)
