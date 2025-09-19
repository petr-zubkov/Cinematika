#!/bin/bash

# Cinematika Remote Installation Script
# Usage: curl -sSL https://your-server.com/Cinematika-remote-install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions for output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Show logo
show_logo() {
    printf "${CYAN}"
    cat << 'EOF'
    ███████╗ ██╗ ███    ██╗ ███████╗ ███      ███╗    █████╗ ███████╗  ██╗ ██╗  ███╗    █████╗  
    ██╔════╝ ██║ ██║█   ██║ ██╔════╝ ██║█   █ ██║    ██╔██║     ██╔═╝  ██║ ██║ ██╔═╝    ██╔██║ 
    ██║        ██║ ██║ █  ██║ █████╗    ██║ █ █  ██║   ██████║    ██║     ██║ ████╔╝       ██████║ 
    ██║        ██║ ██║  █ ██║ ██╔══╝    ██║  █   ██║   ██╔═██║     ██║     ██║ ██╔██╗      ██╔═██║ 
    ███████╗ ██║ ██║   ███║ ███████╗ ██║       ██║  ██║  ██║     ██║     ██║ ██╗  ██║   ██║   ██║
     ╚═════╝ ╚═╝ ╚═╝     ╚═╝ ╚══════╝ ╚═╝       ╚═╝  ╚═╝  ╚═╝     ╚═╝     ╚═╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝
EOF
    printf "${NC}"
    echo ""
}

# Check requirements
check_requirements() {
    log_step "Checking system requirements..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Unsupported operating system"
        exit 1
    fi
    
    # Check sudo privileges
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo privileges!"
        echo "Please run with sudo or ask your administrator for sudo access."
        echo ""
        echo "Without sudo, you can use our minimal version:"
        echo "1. Download: wget https://your-server.com/no-sudo-install.sh"
        echo "2. Run: chmod +x no-sudo-install.sh && ./no-sudo-install.sh"
        exit 1
    fi
    
    log_success "System requirements met"
}

# Get installation parameters
get_install_parameters() {
    log_step "Getting installation parameters..."
    
    # Default parameters
    DOMAIN=${CP_DOMAIN:-}
    LANGUAGE=${CP_LANG:-en}
    THEME=${CP_THEME:-default}
    PASSWORD=${CP_PASSWD:-}
    
    # If domain not specified, ask
    if [ -z "$DOMAIN" ]; then
        echo ""
        echo "Please enter your domain name:"
        read -p "Domain (example.com): " DOMAIN
        
        if [ -z "$DOMAIN" ]; then
            log_error "Domain is required!"
            exit 1
        fi
    fi
    
    # Validate domain
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $DOMAIN"
        exit 1
    fi
    
    # If language not specified, use default
    if [ -z "$LANGUAGE" ]; then
        LANGUAGE="en"
    fi
    
    # If theme not specified, use default
    if [ -z "$THEME" ]; then
        THEME="default"
    fi
    
    # If password not specified, generate
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
        log_info "Generated password: $PASSWORD"
    fi
    
    log_success "Installation parameters configured"
    log_info "Domain: $DOMAIN"
    log_info "Language: $LANGUAGE"
    log_info "Theme: $THEME"
    log_info "Password: ${PASSWORD:0:4}****"
}

# Update system
update_system() {
    log_step "Updating system packages..."
    
    # Determine package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        UPDATE_CMD="sudo apt-get update -qq"
        UPGRADE_CMD="sudo apt-get upgrade -y -qq"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        UPDATE_CMD="sudo yum update -y"
        UPGRADE_CMD="sudo yum upgrade -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        UPDATE_CMD="sudo dnf update -y"
        UPGRADE_CMD="sudo dnf upgrade -y"
    else
        log_error "No supported package manager found"
        exit 1
    fi
    
    log_info "Using package manager: $PKG_MANAGER"
    
    # Update system
    eval "$UPDATE_CMD" || log_warn "System update failed, continuing..."
    eval "$UPGRADE_CMD" || log_warn "System upgrade failed, continuing..."
    
    log_success "System updated"
}

# Install base packages
install_base_packages() {
    log_step "Installing base packages..."
    
    # Base packages for different systems
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        PACKAGES="curl wget git nano htop ca-certificates openssl net-tools cron zip unzip"
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $PACKAGES || {
            log_error "Failed to install base packages"
            exit 1
        }
    elif [ "$PKG_MANAGER" = "yum" ]; then
        PACKAGES="curl wget git nano htop ca-certificates openssl net-tools cron zip unzip"
        sudo yum install -y $PACKAGES || {
            log_error "Failed to install base packages"
            exit 1
        }
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        PACKAGES="curl wget git nano htop ca-certificates openssl net-tools cron zip unzip"
        sudo dnf install -y $PACKAGES || {
            log_error "Failed to install base packages"
            exit 1
        }
    fi
    
    log_success "Base packages installed"
}

# Install Docker
install_docker() {
    log_step "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker already installed: $(docker --version)"
        return
    fi
    
    # Install Docker based on distribution
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        # Remove old versions
        sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Install dependencies
        sudo apt-get install -y -qq ca-certificates curl gnupg
        
        # Add Docker's official GPG key
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Add repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
        # Remove old versions
        sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
        
        # Install repository
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        # Install Docker
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
}

# Create project
create_project() {
    log_step "Creating project structure..."
    
    # Create project directory
    PROJECT_DIR="/home/$DOMAIN"
    sudo mkdir -p "$PROJECT_DIR"
    sudo chown -R $USER:$USER "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Create subdirectories
    mkdir -p config data logs ssl public/static views
    
    log_success "Project structure created"
}

# Create basic Cinematika structure
create_basic_structure() {
    log_step "Creating Cinematika structure..."
    
    # Create package.json
    cat > package.json << EOF
{
  "name": "Cinematika-$DOMAIN",
  "version": "1.0.0",
  "description": "Cinematika website for $DOMAIN",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.0.0",
    "ejs": "^3.1.9",
    "dotenv": "^16.0.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.0",
    "multer": "^1.4.5",
    "sharp": "^0.32.0",
    "helmet": "^6.0.0",
    "cors": "^2.8.5",
    "express-rate-limit": "^6.0.0",
    "compression": "^1.7.4"
  },
  "devDependencies": {
    "nodemon": "^2.0.20"
  },
  "engines": {
    "node": ">=16.0.0"
  }
}
EOF

    # Create main app
    cat > app.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const DOMAIN = process.env.DOMAIN || 'localhost';

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Static files
app.use(express.static(path.join(__dirname, 'public')));
app.use('/static', express.static(path.join(__dirname, 'public/static')));

// View engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Database connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://database:27017/Cinematika', {
    useNewUrlParser: true,
    useUnifiedTopology: true
}).then(() => {
    console.log('✅ Connected to MongoDB');
}).catch(err => {
    console.log('❌ MongoDB connection error:', err);
});

// Basic routes
app.get('/', (req, res) => {
    res.render('index', {
        title: 'Cinematika',
        domain: DOMAIN,
        theme: process.env.THEME || 'default'
    });
});

app.get('/admin', (req, res) => {
    res.render('admin', {
        title: 'Admin Panel',
        domain: DOMAIN
    });
});

// API routes
app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        domain: DOMAIN,
        uptime: process.uptime()
    });
});

app.get('/api/movies', async (req, res) => {
    try {
        // Placeholder for movie data
        const movies = [
            { id: 1, title: 'Sample Movie 1', year: 2024, genre: 'Action', rating: 8.5 },
            { id: 2, title: 'Sample Movie 2', year: 2024, genre: 'Comedy', rating: 7.2 },
            { id: 3, title: 'Sample Movie 3', year: 2024, genre: 'Drama', rating: 8.0 }
        ];
        res.json({ movies, total: movies.length });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).render('error', {
        title: 'Error',
        message: 'Something went wrong!'
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).render('404', {
        title: 'Page Not Found',
        url: req.originalUrl
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Cinematika server running on port ${PORT}`);
    console.log(`🌐 Website: http://${DOMAIN}`);
    console.log(`🔧 Admin: http://${DOMAIN}/admin`);
    console.log(`📊 API: http://${DOMAIN}/api/health`);
});
EOF

    # Create .env file
    cat > .env << EOF
NODE_ENV=production
PORT=3000
DOMAIN=$DOMAIN
LANGUAGE=$LANGUAGE
THEME=$THEME
ADMIN_PASSWORD=$PASSWORD
MONGODB_URI=mongodb://database:27017/Cinematika
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
EOF

    # Create Dockerfile
    cat > Dockerfile << EOF
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
EOF

    # Create docker-compose.yml
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    build: .
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_app
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - DOMAIN=$DOMAIN
      - LANGUAGE=$LANGUAGE
      - THEME=$THEME
      - ADMIN_PASSWORD=$PASSWORD
      - MONGODB_URI=mongodb://database:27017/Cinematika
    volumes:
      - .:/app
      - ./data:/app/data
      - ./logs:/app/logs
    depends_on:
      - database
    networks:
      - Cinematika_network
    ports:
      - "3000:3000"

  database:
    image: mongo:6
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_db
    restart: unless-stopped
    volumes:
      - mongodb_data:/data/db
    networks:
      - Cinematika_network

  nginx:
    image: nginx:alpine
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - app
    networks:
      - Cinematika_network

volumes:
  mongodb_data:

networks:
  Cinematika_network:
    driver: bridge
EOF

    # Create nginx configuration
    cat > nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:3000;
    }

    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;

        location / {
            proxy_pass http://app;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /static/ {
            alias /app/public/static/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

    # Create basic EJS templates
    mkdir -p views
    cat > views/index.ejs << EOF
<!DOCTYPE html>
<html lang="<%= LANGUAGE %>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= title %> - <%= domain %></title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="/"><%= title %></a>
            <div class="navbar-nav ms-auto">
                <a class="nav-link" href="/">Home</a>
                <a class="nav-link" href="/movies">Movies</a>
                <a class="nav-link" href="/series">Series</a>
                <a class="nav-link" href="/admin">Admin</a>
            </div>
        </div>
    </nav>

    <div class="container mt-4">
        <div class="row">
            <div class="col-12">
                <h1>Welcome to <%= title %></h1>
                <p>Your cinema website is ready!</p>
                
                <div class="row">
                    <div class="col-md-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Latest Movies</h5>
                                <p class="card-text">Check out our latest movie collection.</p>
                                <a href="/movies" class="btn btn-primary">View Movies</a>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">TV Series</h5>
                                <p class="card-text">Watch your favorite TV series.</p>
                                <a href="/series" class="btn btn-primary">View Series</a>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Admin Panel</h5>
                                <p class="card-text">Manage your content and settings.</p>
                                <a href="/admin" class="btn btn-primary">Admin Panel</a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF

    cat > views/admin.ejs << EOF
<!DOCTYPE html>
<html lang="<%= LANGUAGE %>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= title %> - <%= domain %></title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="/">Cinematika Admin</a>
            <div class="navbar-nav ms-auto">
                <a class="nav-link" href="/">Back to Site</a>
            </div>
        </div>
    </nav>

    <div class="container mt-4">
        <div class="row">
            <div class="col-12">
                <h1>Admin Panel</h1>
                <p>Welcome to the Cinematika administration interface.</p>
                
                <div class="row">
                    <div class="col-md-3">
                        <div class="list-group">
                            <a href="#" class="list-group-item list-group-item-action active">Dashboard</a>
                            <a href="#" class="list-group-item list-group-item-action">Movies</a>
                            <a href="#" class="list-group-item list-group-item-action">Series</a>
                            <a href="#" class="list-group-item list-group-item-action">Users</a>
                            <a href="#" class="list-group-item list-group-item-action">Settings</a>
                        </div>
                    </div>
                    <div class="col-md-9">
                        <div class="card">
                            <div class="card-header">
                                <h5>System Status</h5>
                            </div>
                            <div class="card-body">
                                <div class="row">
                                    <div class="col-md-6">
                                        <p><strong>Domain:</strong> <%= domain %></p>
                                        <p><strong>Theme:</strong> <%= theme %></p>
                                        <p><strong>Language:</strong> <%= LANGUAGE %></p>
                                    </div>
                                    <div class="col-md-6">
                                        <p><strong>Node.js:</strong> <%= process.version %></p>
                                        <p><strong>Environment:</strong> <%= process.env.NODE_ENV %></p>
                                        <p><strong>Port:</strong> <%= process.env.PORT %></p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF

    log_success "Cinematika structure created"
}

# Start services
start_services() {
    log_step "Starting services..."
    
    # Start Docker containers
    docker-compose up -d
    
    # Wait for services to start
    sleep 10
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        log_success "Services started successfully"
    else
        log_error "Failed to start services"
        exit 1
    fi
}

# Show completion message
show_completion() {
    echo ""
    echo "${GREEN}🎉 Installation completed successfully!${NC}"
    echo ""
    echo "${BLUE}📋 Installation Details:${NC}"
    echo "  Domain: ${CYAN}$DOMAIN${NC}"
    echo "  Language: ${CYAN}$LANGUAGE${NC}"
    echo "  Theme: ${CYAN}$THEME${NC}"
    echo "  Admin Password: ${CYAN}$PASSWORD${NC}"
    echo ""
    echo "${BLUE}🌐 Access URLs:${NC}"
    echo "  Website: ${CYAN}http://$DOMAIN${NC}"
    echo "  Admin Panel: ${CYAN}http://$DOMAIN/admin${NC}"
    echo "  API Health: ${CYAN}http://$DOMAIN/api/health${NC}"
    echo ""
    echo "${BLUE}🔧 Useful Commands:${NC}"
    echo "  View status: ${CYAN}docker-compose ps${NC}"
    echo "  View logs: ${CYAN}docker-compose logs -f${NC}"
    echo "  Stop services: ${CYAN}docker-compose down${NC}"
    echo "  Restart services: ${CYAN}docker-compose restart${NC}"
    echo ""
    echo "${YELLOW}⚠️  Important Notes:${NC}"
    echo "  1. Make sure your domain DNS points to this server"
    echo "  2. Configure SSL certificate for HTTPS (optional)"
    echo "  3. Change the default admin password"
    echo "  4. Regularly update your system and containers"
    echo ""
    echo "${GREEN}✅ Cinematika is now ready to use!${NC}"
}

# Main installation function
main() {
    show_logo
    check_requirements
    get_install_parameters
    update_system
    install_base_packages
    install_docker
    create_project
    create_basic_structure
    start_services
    show_completion
}

# Run main function
main "$@"