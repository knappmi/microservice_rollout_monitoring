# Authentication Setup Guide

Before publishing to Docker Hub and GitHub Container Registry (GHCR), you need to set up authentication.

## 🐳 Docker Hub Setup

### 1. Create Docker Hub Account
- Go to [hub.docker.com](https://hub.docker.com)
- Sign up or login to your account

### 2. Login via CLI
```powershell
docker login
# Enter your Docker Hub username and password
```

## 🐙 GitHub Container Registry (GHCR) Setup

### 1. Create GitHub Personal Access Token
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes:
   - ✅ `write:packages` (Upload packages to GitHub Package Registry)
   - ✅ `read:packages` (Download packages from GitHub Package Registry)
   - ✅ `delete:packages` (Delete packages from GitHub Package Registry) - optional
4. Copy the token (you won't see it again!)

### 2. Login to GHCR
```powershell
# Login using your GitHub username and the token as password
docker login ghcr.io
Username: your-github-username
Password: ghp_your-personal-access-token
```

## 🚀 Quick Publishing Commands

### Publish to Both Registries
```powershell
# Replace 'yourusername' with your actual usernames
.\publish-to-registries.ps1 -DockerHubUsername "yourusername" -GitHubUsername "yourusername" -Version "1.0.0"
```

### Publish to Docker Hub Only
```powershell
.\publish-to-registries.ps1 -DockerHubUsername "yourusername" -Version "1.0.0" -SkipGHCR
```

### Publish to GHCR Only
```powershell
.\publish-to-registries.ps1 -GitHubUsername "yourusername" -Version "1.0.0" -SkipDockerHub
```

## 📦 Published Image URLs

After publishing, your images will be available at:

### Docker Hub
- `docker pull yourusername/observability-demo-app:latest`
- `docker pull yourusername/observability-demo-app:1.0.0`

### GitHub Container Registry
- `docker pull ghcr.io/yourusername/observability-demo-app:latest`
- `docker pull ghcr.io/yourusername/observability-demo-app:1.0.0`

## 🔒 Making GHCR Package Public

By default, GHCR packages are private. To make them public:

1. Go to your GitHub profile → Packages
2. Find your `observability-demo-app` package
3. Click on it → Package settings
4. Scroll down to "Danger Zone"
5. Click "Change visibility" → "Public"

## ✅ Verification

Test your published images:

```powershell
# Test Docker Hub image
docker run -p 5000:5000 yourusername/observability-demo-app:latest

# Test GHCR image  
docker run -p 5000:5000 ghcr.io/yourusername/observability-demo-app:latest
```

Visit: http://localhost:5000/health

## 🛠️ Troubleshooting

### Docker Hub Issues
- **"unauthorized"**: Check username/password, ensure account exists
- **"denied"**: Repository might not exist or you don't have push access

### GHCR Issues
- **"unauthorized"**: Check token permissions, ensure `write:packages` is enabled
- **"403 Forbidden"**: Token might be expired or lack proper permissions
- **Package not visible**: May be private by default, change visibility to public

### General Issues
- **"image not found"**: Ensure you built the image first
- **Network issues**: Check internet connection and proxy settings
- **Permission denied**: Ensure Docker daemon is running and you have access

## 🔄 Updating Images

To update an existing image:

1. Update your version number
2. Run the publish script with the new version
3. Both `latest` and versioned tags will be updated

Example:
```powershell
.\publish-to-registries.ps1 -DockerHubUsername "yourusername" -Version "1.1.0"
```
