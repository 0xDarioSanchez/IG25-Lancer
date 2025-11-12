//!
//! Lancer Protocol - Arbitrum Stylus Implementation
//!
//! This library contains two main contracts:
//! - Marketplace: Handles deals between payers and beneficiaries
//! - Protocol: Manages dispute resolution with judge voting
//!
//! Original Solidity contracts converted to Rust for Arbitrum Stylus
//! @author 0xDarioSanchez
//!
//! Note: this code is a conversion and has not been audited.
//!

#![cfg_attr(not(feature = "export-abi"), no_main)]

// Only one entrypoint can be active at a time
// To switch contracts:
// 1. Comment/uncomment the module you want below
// 2. Update main.rs to match
pub mod protocol;
// pub mod marketplace;
