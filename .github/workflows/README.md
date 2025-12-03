# GitHub Actions Deployment Setup

This workflow automatically builds a Docker image and deploys the application to AWS EC2 when code is pushed to the `main` or `master` branch.

## Required GitHub Secrets

Configure the following secrets in your GitHub repository settings (Settings → Secrets and variables → Actions):

### AWS Credentials
- `AWS_ACCESS_KEY_ID` - Your AWS access key ID
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret access key

### EC2 Connection Details
- `EC2_HOST` - Your EC2 instance IP address or domain name (e.g., `ec2-xx-xx-xx-xx.compute-1.amazonaws.com` or `54.123.45.67`)
- `EC2_USER` - SSH username (typically `ec2-user` for Amazon Linux, `ubuntu` for Ubuntu)
- `EC2_SSH_KEY` - Your private SSH key content (the entire content of your `.pem` file)

### Database Connection
- `POSTGRES_CONNECTION_STRING` - PostgreSQL connection string (required for Docker deployment)
  - Format: `Host=your-db-host;Port=5432;Database=WebApiDb;Username=user;Password=pass`

### Docker Registry (Optional - for registry-based deployment)
- `DOCKER_USERNAME` - Your Docker Hub username (if using Docker Hub)
- `DOCKER_PASSWORD` - Your Docker Hub password or access token
- `AWS_ECR_REGISTRY` - Your AWS ECR registry URL (if using AWS ECR)
  - Format: `your-account-id.dkr.ecr.region.amazonaws.com`

## How to Add Secrets

1. Go to your GitHub repository
2. Click on **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the exact name listed above

## EC2 Instance Prerequisites

Your EC2 instance must have:

1. **Docker** installed and running:
   ```bash
   # For Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y docker.io
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   
   # Log out and log back in for group changes to take effect
   ```

2. **Docker Compose** (optional, for docker-compose deployments):
   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

3. **Security Group** configured to allow:
   - Port 22 (SSH) from GitHub Actions IPs or your IP
   - Port 8080 (HTTP) from your desired sources

4. **SSH Access** configured with your key pair

## Deployment Process

The workflow performs the following steps:

1. **Build Docker Image Job**: 
   - Checks out code
   - Sets up Docker Buildx
   - Builds Docker image using the Dockerfile
   - Saves Docker image as tar.gz
   - Uploads Docker image as artifact

2. **Deploy Docker Job**:
   - Downloads Docker image artifact
   - Configures AWS credentials
   - Copies Docker image to EC2 via SCP
   - Loads Docker image on EC2
   - Stops and removes old container (if exists)
   - Runs new Docker container with environment variables
   - Verifies deployment by checking container status and testing API endpoint

### Alternative: Registry-Based Deployment

If you prefer to use a Docker registry (Docker Hub or AWS ECR), you can enable the `docker-registry-deploy` job by setting `if: true` in the workflow file. This will:
- Push the Docker image to your registry
- Pull the image on EC2 from the registry
- Deploy the container from the registry

## Manual Deployment Trigger

You can manually trigger the workflow:
1. Go to **Actions** tab in your repository
2. Select **Build and Deploy to AWS EC2** workflow
3. Click **Run workflow**
4. Choose the branch and environment
5. Click **Run workflow**

## Troubleshooting

### Deployment fails with SSH connection error
- Verify `EC2_HOST`, `EC2_USER`, and `EC2_SSH_KEY` secrets are correct
- Ensure EC2 security group allows SSH from GitHub Actions
- Check that the SSH key has correct permissions (chmod 600)

### Application doesn't start
- Check Docker container logs: `docker logs webapi-container`
- Verify Docker is running: `sudo systemctl status docker`
- Check container status: `docker ps -a`
- View container logs: `docker logs webapi-container --tail 100`

### Port already in use
- Check what's using port 8080: `sudo lsof -i :8080` or `sudo netstat -tulpn | grep 8080`
- Stop conflicting container: `docker stop <container-name>`
- Or change port mapping in the workflow deployment step

### Database connection issues
- Verify PostgreSQL is accessible from EC2
- Check connection string format
- Ensure security groups allow database access

## Monitoring

After deployment, monitor your application:

```bash
# Check container status
docker ps | grep webapi-container

# View container logs
docker logs webapi-container -f

# View last 100 lines of logs
docker logs webapi-container --tail 100

# Test API endpoint
curl http://localhost:8080/api/Products

# Check container health
docker inspect webapi-container | grep -A 10 Health
```

## Rollback

To rollback to a previous version:

1. Find the previous successful workflow run
2. Download the artifacts from that run
3. Manually deploy or re-run the workflow for that commit

