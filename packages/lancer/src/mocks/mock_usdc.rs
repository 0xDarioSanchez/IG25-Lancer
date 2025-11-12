//!
//! Mock USDC ERC20 Token - Arbitrum Stylus Implementation
//!
//! This contract implements a simple ERC20 token for testing purposes
//! with USDC-like properties (6 decimals, mintable).
//!
//! @author 0xDarioSanchez
//!
//! Note: For testing purposes only, not audited.
//!

extern crate alloc;

use alloc::string::String;
use stylus_sdk::{
    alloy_primitives::{Address, U256, U8},
    prelude::*,
    evm,
    msg,
};
use alloy_sol_types::sol;

// ====================================
//          STORAGE STRUCTS          
// ====================================

sol_storage! {
    #[entrypoint]
    pub struct MockUSDC {
        string name;
        string symbol;
        uint8 decimals;
        uint256 total_supply;
        
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        address owner;
    }
}

// ====================================
//             EVENTS          
// ====================================

sol! {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount);
    
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidAddress();
    error NotOwner();
}

// ====================================
//          ERROR TYPES          
// ====================================

#[derive(SolidityError)]
pub enum MockUSDCError {
    InsufficientBalance(InsufficientBalance),
    InsufficientAllowance(InsufficientAllowance),
    InvalidAddress(InvalidAddress),
    NotOwner(NotOwner),
}

// ====================================
//        IMPLEMENTATION          
// ====================================

#[public]
impl MockUSDC {
    
    /// Initialize the token
    pub fn init(&mut self, owner: Address) -> Result<(), MockUSDCError> {
        self.name.set_str("Mock USDC");
        self.symbol.set_str("USDC");
        self.decimals.set(U8::from(6u8));
        self.total_supply.set(U256::ZERO);
        self.owner.set(owner);
        
        Ok(())
    }
    
    // ====================================
    //        ERC20 FUNCTIONS          
    // ====================================
    
    /// Get token name
    pub fn name(&self) -> String {
        self.name.get_string()
    }
    
    /// Get token symbol
    pub fn symbol(&self) -> String {
        self.symbol.get_string()
    }
    
    /// Get decimals (6 for USDC)
    pub fn decimals(&self) -> u8 {
        u8::from_le_bytes(self.decimals.get().to_le_bytes())
    }
    
    /// Get total supply
    pub fn total_supply(&self) -> U256 {
        self.total_supply.get()
    }
    
    /// Get balance of an account
    pub fn balance_of(&self, account: Address) -> U256 {
        self.balances.get(account)
    }
    
    /// Transfer tokens
    pub fn transfer(&mut self, to: Address, amount: U256) -> Result<bool, MockUSDCError> {
        let sender = msg::sender();
        
        if to == Address::ZERO {
            return Err(MockUSDCError::InvalidAddress(InvalidAddress {}));
        }
        
        let sender_balance = self.balances.get(sender);
        if sender_balance < amount {
            return Err(MockUSDCError::InsufficientBalance(InsufficientBalance {}));
        }
        
        // Update balances
        self.balances.setter(sender).set(sender_balance - amount);
        let receiver_balance = self.balances.get(to);
        self.balances.setter(to).set(receiver_balance + amount);
        
        evm::log(Transfer {
            from: sender,
            to,
            value: amount,
        });
        
        Ok(true)
    }
    
    /// Approve spender to spend tokens
    pub fn approve(&mut self, spender: Address, amount: U256) -> Result<bool, MockUSDCError> {
        let sender = msg::sender();
        
        if spender == Address::ZERO {
            return Err(MockUSDCError::InvalidAddress(InvalidAddress {}));
        }
        
        self.allowances.setter(sender).setter(spender).set(amount);
        
        evm::log(Approval {
            owner: sender,
            spender,
            value: amount,
        });
        
        Ok(true)
    }
    
    /// Get allowance
    pub fn allowance(&self, owner: Address, spender: Address) -> U256 {
        self.allowances.get(owner).get(spender)
    }
    
    /// Transfer tokens from an account (requires approval)
    pub fn transfer_from(
        &mut self,
        from: Address,
        to: Address,
        amount: U256,
    ) -> Result<bool, MockUSDCError> {
        let sender = msg::sender();
        
        if to == Address::ZERO {
            return Err(MockUSDCError::InvalidAddress(InvalidAddress {}));
        }
        
        // Check balance
        let from_balance = self.balances.get(from);
        if from_balance < amount {
            return Err(MockUSDCError::InsufficientBalance(InsufficientBalance {}));
        }
        
        // Check allowance
        let current_allowance = self.allowances.get(from).get(sender);
        if current_allowance < amount {
            return Err(MockUSDCError::InsufficientAllowance(InsufficientAllowance {}));
        }
        
        // Update allowance
        self.allowances.setter(from).setter(sender).set(current_allowance - amount);
        
        // Update balances
        self.balances.setter(from).set(from_balance - amount);
        let to_balance = self.balances.get(to);
        self.balances.setter(to).set(to_balance + amount);
        
        evm::log(Transfer {
            from,
            to,
            value: amount,
        });
        
        Ok(true)
    }
    
    // ====================================
    //        MINT FUNCTION (FOR TESTING)
    // ====================================
    
    /// Mint tokens to an account (only owner)
    pub fn mint(&mut self, to: Address, amount: U256) -> Result<(), MockUSDCError> {
        let sender = msg::sender();
        
        if sender != self.owner.get() {
            return Err(MockUSDCError::NotOwner(NotOwner {}));
        }
        
        if to == Address::ZERO {
            return Err(MockUSDCError::InvalidAddress(InvalidAddress {}));
        }
        
        // Update balance
        let balance = self.balances.get(to);
        self.balances.setter(to).set(balance + amount);
        
        // Update total supply
        let total = self.total_supply.get();
        self.total_supply.set(total + amount);
        
        evm::log(Mint { to, amount });
        
        evm::log(Transfer {
            from: Address::ZERO,
            to,
            value: amount,
        });
        
        Ok(())
    }
    
    /// Get owner address
    pub fn owner(&self) -> Address {
        self.owner.get()
    }
}
