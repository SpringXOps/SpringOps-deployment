#!/bin/bash

# Function for spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to run a command with a loading animation
run_with_spinner() {
    local message=$1
    shift
    echo -n "$message"
    "$@" &> /dev/null &
    spinner $!
    echo " Done!"
}

# Function to install Python
install_python() {
    run_with_spinner "Adding Python 3.12 repository..." sudo add-apt-repository ppa:deadsnakes/ppa -y
    run_with_spinner "Updating package lists..." sudo apt update
    run_with_spinner "Installing Python 3.12..." sudo apt install -y python3.12 python3.12-venv python3.12-dev
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
    sudo update-alternatives --set python3 /usr/bin/python3.12
}

# Function to remove Python
remove_python() {
    run_with_spinner "Removing Python 3.12..." sudo apt remove -y python3.12 python3.12-venv python3.12-dev
    sudo update-alternatives --remove python3 /usr/bin/python3.12
}

# Function to install Docker and Docker Compose
install_docker() {
    run_with_spinner "Adding Docker GPG key..." curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    run_with_spinner "Updating package lists..." sudo apt update
    run_with_spinner "Installing Docker..." sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    run_with_spinner "Installing Docker Compose..." sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}

# Function to remove Docker and Docker Compose
remove_docker() {
    run_with_spinner "Removing Docker..." sudo apt remove -y docker-ce docker-ce-cli containerd.io
    sudo rm /usr/local/bin/docker-compose
}

# Function to install Node.js and npm
install_node() {
    echo "Starting Node.js and npm installation..."

    # Remove old versions and repositories
    run_with_spinner "Removing old Node.js (if exists)..." sudo apt-get remove -y nodejs nodejs-doc
    run_with_spinner "Removing old Node.js repositories..." sudo rm -rf /etc/apt/sources.list.d/nodesource.list*

    # Install curl if not already installed
    if ! command -v curl &> /dev/null; then
        run_with_spinner "Installing curl..." sudo apt-get install -y curl
    fi

    # Download and run the NodeSource setup script
    echo "Adding NodeSource repository for Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

    # Install Node.js
    run_with_spinner "Installing Node.js 20.x LTS..." sudo apt-get install -y nodejs

    # Check if Node.js is installed correctly
    if ! command -v node &> /dev/null; then
        echo "Error: Node.js installation failed."
        return 1
    fi

    # Check if npm is installed correctly
    if ! command -v npm &> /dev/null; then
        echo "npm not found. Attempting to install npm separately..."
        run_with_spinner "Installing npm..." sudo apt-get install -y npm
    fi

    # Check again if npm is installed
    if ! command -v npm &> /dev/null; then
        echo "Error: npm installation failed."
        return 1
    fi

    # Update npm to the latest version
    run_with_spinner "Updating npm..." sudo npm install -g npm@latest

    # Print installed versions
    node_version=$(node --version)
    npm_version=$(npm --version)
    echo "Node.js $node_version and npm $npm_version have been installed."
}

# Function to remove Node.js
remove_node() {
    run_with_spinner "Removing Node.js and npm..." sudo apt-get remove -y nodejs npm
    run_with_spinner "Removing NodeSource repository..." sudo rm -rf /etc/apt/sources.list.d/nodesource.list*
    run_with_spinner "Cleaning up..." sudo apt-get autoremove -y
    echo "Node.js and npm have been removed."
}
# Function to install Java (OpenJDK)
install_java() {
    run_with_spinner "Installing OpenJDK 17..." sudo apt install -y openjdk-17-jdk
}

# Function to remove Java (OpenJDK)
remove_java() {
    run_with_spinner "Removing OpenJDK..." sudo apt remove -y openjdk-17-jdk
}

# Main menu function
main_menu() {
    while true; do
        echo "1. Install/Update components"
        echo "2. Remove components"
        echo "3. Exit"
        read -p "Choose an option: " choice

        case $choice in
            1)
                install_menu
                ;;
            2)
                remove_menu
                ;;
            3)
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Install menu function
install_menu() {
    echo "Select components to install/update:"
    echo "1. Python 3.12"
    echo "2. Docker and Docker Compose"
    echo "3. Node.js LTS"
    echo "4. Java (OpenJDK 17)"
    echo "5. All components"
    echo "6. Back to main menu"
    read -p "Enter your choice (1-6): " install_choice

    case $install_choice in
        1) install_python ;;
        2) install_docker ;;
        3) install_node ;;
        4) install_java ;;
        5)
            install_python
            install_docker
            install_node
            install_java
            ;;
        6) return ;;
        *) echo "Invalid option. Please try again." ;;
    esac
}

# Remove menu function
remove_menu() {
    echo "Select components to remove:"
    echo "1. Python 3.12"
    echo "2. Docker and Docker Compose"
    echo "3. Node.js"
    echo "4. Java (OpenJDK)"
    echo "5. All components"
    echo "6. Back to main menu"
    read -p "Enter your choice (1-6): " remove_choice

    case $remove_choice in
        1) remove_python ;;
        2) remove_docker ;;
        3) remove_node ;;
        4) remove_java ;;
        5)
            remove_python
            remove_docker
            remove_node
            remove_java
            ;;
        6) return ;;
        *) echo "Invalid option. Please try again." ;;
    esac
}

# Run the main menu
main_menu