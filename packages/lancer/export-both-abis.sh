#!/bin/bash
# Script to export both Protocol and Marketplace ABIs

echo "========================================="
echo "Exporting Protocol ABI..."
echo "========================================="

# Protocol is already enabled by default
cargo stylus export-abi > protocol-abi.txt 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Protocol ABI exported to protocol-abi.txt"
else
    echo "✗ Failed to export Protocol ABI"
    cat protocol-abi.txt
fi

echo ""
echo "========================================="
echo "Exporting Marketplace ABI..."
echo "========================================="

# Temporarily switch to marketplace
sed -i 's/^pub mod protocol;$/\/\/ pub mod protocol;/' src/lib.rs
sed -i 's/^\/\/ pub mod marketplace;$/pub mod marketplace;/' src/lib.rs
sed -i 's/lancer::protocol::print_abi/\/\/ lancer::protocol::print_abi/' src/main.rs
sed -i 's/\/\/ lancer::marketplace::print_abi/lancer::marketplace::print_abi/' src/main.rs

cargo stylus export-abi > marketplace-abi.txt 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Marketplace ABI exported to marketplace-abi.txt"
else
    echo "✗ Failed to export Marketplace ABI"
    cat marketplace-abi.txt
fi

# Switch back to protocol
sed -i 's/^\/\/ pub mod protocol;$/pub mod protocol;/' src/lib.rs
sed -i 's/^pub mod marketplace;$/\/\/ pub mod marketplace;/' src/lib.rs
sed -i 's/\/\/ lancer::protocol::print_abi/lancer::protocol::print_abi/' src/main.rs
sed -i 's/lancer::marketplace::print_abi/\/\/ lancer::marketplace::print_abi/' src/main.rs

echo ""
echo "========================================="
echo "Done! Both ABIs exported."
echo "========================================="
