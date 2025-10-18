# ============================================
# PHASE 7: VM Guest Tools (VirtualBox or VMware)
# ============================================
phase7_vm_guest_tools() {
    log_info "Phase 7: Detecting virtualization environment"
    
    # Detect VirtualBox
    if lspci | grep -i "virtualbox" > /dev/null 2>&1 || dmidecode -s system-product-name 2>/dev/null | grep -i "virtualbox" > /dev/null 2>&1; then
        log_info "VirtualBox detected! Installing Guest Additions for bidirectional clipboard"
        
        # Install required dependencies
        apt install -y \
            build-essential \
            dkms \
            linux-headers-$(uname -r) \
            module-assistant \
            perl
        
        # Prepare module-assistant
        m-a prepare
        
        # Download VirtualBox Guest Additions ISO
        VBOX_VERSION=$(VBoxControl --version 2>/dev/null | cut -d 'r' -f1)
        if [ -z "$VBOX_VERSION" ]; then
            # Fallback to latest stable version
            VBOX_VERSION="7.0.14"
            log_warn "Could not detect VBox version, using default: $VBOX_VERSION"
        fi
        
        log_info "Downloading VirtualBox Guest Additions $VBOX_VERSION"
        wget "https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso" \
            -O /tmp/VBoxGuestAdditions.iso
        
        # Mount and install
        mkdir -p /mnt/vbox
        mount -o loop /tmp/VBoxGuestAdditions.iso /mnt/vbox
        
        log_info "Installing VirtualBox Guest Additions"
        cd /mnt/vbox
        ./VBoxLinuxAdditions.run --nox11 || true  # May fail on some modules, that's OK
        
        # Enable bidirectional clipboard and drag-and-drop
        log_info "Enabling bidirectional clipboard and drag-and-drop"
        VBoxClient --clipboard &
        VBoxClient --draganddrop &
        VBoxClient --seamless &
        
        # Add to jamie's autostart
        sudo -u jamie mkdir -p $USER_HOME/.config/autostart
        
        cat > $USER_HOME/.config/autostart/vboxclient-clipboard.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Clipboard
Exec=VBoxClient --clipboard
X-GNOME-Autostart-enabled=true
EOF

        cat > $USER_HOME/.config/autostart/vboxclient-draganddrop.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Drag and Drop
Exec=VBoxClient --draganddrop
X-GNOME-Autostart-enabled=true
EOF

        cat > $USER_HOME/.config/autostart/vboxclient-seamless.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Seamless
Exec=VBoxClient --seamless
X-GNOME-Autostart-enabled=true
EOF
        
        chown -R jamie:jamie $USER_HOME/.config
        
        # Cleanup
        umount /mnt/vbox
        rm /tmp/VBoxGuestAdditions.iso
        
        log_info "VirtualBox Guest Additions installed successfully"
        log_warn "IMPORTANT: Reboot the VM for full functionality"
        
    # Detect VMware
    elif lspci | grep -i "vmware" > /dev/null 2>&1 || dmidecode -s system-product-name 2>/dev/null | grep -i "vmware" > /dev/null 2>&1; then
        log_info "VMware detected! Installing open-vm-tools for bidirectional clipboard"
        
        apt install -y \
            open-vm-tools \
            open-vm-tools-desktop
        
        # Enable and start vmtoolsd
        systemctl enable open-vm-tools
        systemctl start open-vm-tools
        
        log_info "VMware Tools installed successfully"
        log_warn "IMPORTANT: Enable 'Copy and Paste' in VMware VM settings"
        
    else
        log_info "No virtualization environment detected (VirtualBox/VMware)"
        log_info "Installing xclip for clipboard management anyway"
        apt install -y xclip xsel
    fi
    
    log_info "Phase 7 complete"
}

# ============================================
# PHASE 8: Post-Install Cleanup
# ============================================
phase8_cleanup() {
    log_info "Phase 8: Cleaning up and finalizing"
    
    # Clean apt cache
    apt autoremove -y
    apt autoclean -y
    
    log_info "Phase 8 complete"
}
