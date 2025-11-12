#![cfg_attr(not(feature = "export-abi"), no_main)]

#[cfg(feature = "export-abi")]
fn main() {
    lancer::protocol::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
    // To export marketplace ABI instead, enable marketplace module in lib.rs and use:
    // lancer::marketplace::print_abi("Apache-2.0", "pragma solidity ^0.8.23;");
}
