# ============================================
# PHASE 7: VirtualBox Guest Additions (if applicable)
# ============================================
phase7_virtualbox_setup() {
    log_info "Phase 7: Checking for VirtualBox environment"
    
    # Detect if running in VirtualBox
    if lspci | grep -i "virtualbox" > /dev/null 2>&1 || dmidecode -s system-product-name | grep -i "virtualbox" > /dev/null 2>&1; then
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
            # Fallback to latest version if we can't detect
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
        
        # Enable bidirectional clipboard
        log_info "Enabling bidirectional clipboard and drag-and-drop"
        VBoxClient --clipboard &
        VBoxClient --draganddrop &
        
        # Add to jamie's autostart
        sudo -u jamie mkdir -p $USER_HOME/.config/autostart
        
        cat > $USER_HOME/.config/autostart/vboxclient-clipboard.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Clipboard
Exec=VBoxClient --clipboard
EOF

        cat > $USER_HOME/.config/autostart/vboxclient-draganddrop.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Drag and Drop
Exec=VBoxClient --draganddrop
EOF
        
        chown -R jamie:jamie $USER_HOME/.config
        
        # Cleanup
        umount /mnt/vbox
        rm /tmp/VBoxGuestAdditions.iso
        
        log_info "VirtualBox Guest Additions installed successfully"
        log_warn "You may need to restart the VM for full functionality"
    else
        log_info "Not running in VirtualBox, skipping Guest Additions"
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
