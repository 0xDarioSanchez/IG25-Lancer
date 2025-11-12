#![cfg_attr(not(feature = "export-abi"), no_main)]

#[cfg(feature = "export-abi")]
fn main() {
    // Export ABI for Protocol contract (Marketplace is commented out in lib.rs)
    lancer::protocol::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
    
    // Note: Uncomment in lib.rs and comment out protocol to export Marketplace ABI
    // lancer::marketplace::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
}
