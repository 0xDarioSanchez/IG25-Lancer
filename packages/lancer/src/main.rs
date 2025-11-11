#![cfg_attr(not(feature = "export-abi"), no_main)]

#[cfg(feature = "export-abi")]
fn main() {
    // Export ABI for Marketplace contract
    stylus_lancer::marketplace::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
    
    // Export ABI for Protocol contract
    stylus_lancer::protocol::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
}
