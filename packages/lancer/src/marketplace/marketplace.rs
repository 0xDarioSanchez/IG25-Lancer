
//!
//! Lancer Marketplace - Arbitrum Stylus Implementation
//!
//! This contract implements a marketplace for deals between payers and beneficiaries
//! with dispute resolution system.
//!
//! Original Solidity contract converted to Rust for Arbitrum Stylus
//! @author 0xDarioSanchez
//!
//! Note: this code is a conversion and has not been audited.
//!

extern crate alloc;

use alloc::string::String;
use alloy_sol_types::sol;
use stylus_sdk::{
    alloy_primitives::{Address, U256, U64, U8, I8},
    prelude::*,
    block,
    call::Call,
    contract,
    evm,
    msg,
};

// ====================================
//          STORAGE STRUCTS          
// ====================================

sol_storage! {
    #[entrypoint]
    pub struct Marketplace {
        // Immutable state (set once in constructor)
        address owner;
        address usdc_token;
        address protocol;
        
        // Mutable state
        uint64 deal_id_counter;
        uint8 fee_percent;
        
        // Mappings
        mapping(address => User) users;
        mapping(uint256 => Deal) deals;
        mapping(uint64 => Dispute) disputes;
    }
    
    pub struct User {
        address user_address;
        uint256 balance;
        int8 reputation_as_user;
        int8 reputation_as_judge;
        bool is_payer;
        bool is_beneficiary;
        bool is_judge;
        mapping(uint256 => uint64) deals;  // Index => dealId
        uint256 deals_count;
    }
    
    pub struct Deal {
        uint64 deal_id;
        address payer;
        address beneficiary;
        uint256 amount;
        uint256 started_at;
        uint64 duration;
        bool accepted;
        bool disputed;
    }
    
    pub struct Dispute {
        uint64 deal_id;
        address requester;
        bool is_open;
        bool waiting_for_judges;
    }
}

// ====================================
//             EVENTS          
// ====================================

sol! {
    event UserRegistered(address indexed user, bool is_payer, bool is_beneficiary, bool is_judge);
    event DealCreated(uint64 indexed deal_id, address indexed payer, address indexed beneficiary, uint256 amount);
    event DealAccepted(uint64 indexed deal_id);
    event DealRejected(uint64 indexed deal_id);
    event DisputeRequested(uint256 indexed dispute_id, address indexed requester);
    event UserWithdrew(address indexed user, uint256 amount);
    event PaymentDeposited(address indexed user, uint256 amount);
    event DealAmountUpdated(uint64 indexed deal_id, uint256 new_amount);
    event DealFinalized(uint64 indexed deal_id);
    event DealDurationUpdated(uint64 indexed deal_id, uint16 new_duration);
    event DisputeCreated(uint64 indexed deal_id, address indexed requester);
    event DisputeResolved(uint64 indexed dispute_id, address indexed winner);
    event NewFeePercent(uint8 new_fee_percent);
    
    error Unauthorized();
    error NotFound();
    error AlreadyExists();
    error InvalidInput();
    error InvalidState();
    error InsufficientBalance();
    error CallFailed();
}

// ====================================
//          ERROR TYPES          
// ====================================

#[derive(SolidityError)]
pub enum MarketplaceError {
    Unauthorized(Unauthorized),
    NotFound(NotFound),
    AlreadyExists(AlreadyExists),
    InvalidInput(InvalidInput),
    InvalidState(InvalidState),
    InsufficientBalance(InsufficientBalance),
    CallFailed(CallFailed),
}

// Implement From for stylus_sdk::call::Error
impl From<stylus_sdk::call::Error> for MarketplaceError {
    fn from(_error: stylus_sdk::call::Error) -> Self {
        MarketplaceError::CallFailed(CallFailed {})
    }
}

// ====================================
//        CONSTANTS          
// ====================================

const USDC_DECIMALS: u8 = 6;
const ONE_DAY: U256 = U256::from_limbs([86400u64, 0, 0, 0]); // 86400 seconds
const ONE_WEEK: U256 = U256::from_limbs([604800u64, 0, 0, 0]); // 7 days in seconds

// ====================================
//      EXTERNAL INTERFACE CALLS          
// ====================================

sol_interface! {
    interface IERC20 {
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
        function transfer(address to, uint256 amount) external returns (bool);
    }
    
    interface IProtocol {
        function createDispute(uint64 deal_id, address requester, string calldata proof) external;
        function updateDisputeForPayer(uint64 dispute_id, address payer, string calldata proof) external;
        function updateDisputeForBeneficiary(uint64 dispute_id, address beneficiary, string calldata proof) external;
        function executeDisputeResult(uint64 dispute_id) external returns (bool);
    }
}

// ====================================
//        IMPLEMENTATION          
// ====================================

#[public]
impl Marketplace {
    
    // ====================================
    //           CONSTRUCTOR          
    // ====================================
    
    /// Initialize the marketplace contract
    pub fn init(
        &mut self,
        owner: Address,
        fee_percent: u8,
        token: Address,
        protocol_address: Address,
    ) -> Result<(), MarketplaceError> {
        self.owner.set(owner);
        self.fee_percent.set(U8::from(fee_percent));
        self.usdc_token.set(token);
        self.protocol.set(protocol_address);
        self.deal_id_counter.set(U64::from(1));
        Ok(())
    }
    
    // ====================================
    //        ONLY-OWNER FUNCTIONS          
    // ====================================
    
    /// Update the fee percentage
    pub fn set_fee_percent(&mut self, new_fee_percent: u8) -> Result<(), MarketplaceError> {
        if msg::sender() != self.owner.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        self.fee_percent.set(U8::from(new_fee_percent));
        evm::log(NewFeePercent { new_fee_percent });
        
        Ok(())
    }
    
    // ====================================
    //         EXTERNAL FUNCTIONS          
    // ====================================
    
    /// Register a new user with specified roles
    pub fn register_user(
        &mut self,
        is_payer: bool,
        is_beneficiary: bool,
        is_judge: bool,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let mut user = self.users.setter(sender);
        
        // Check if user already registered
        if user.user_address.get() != Address::ZERO {
            return Err(MarketplaceError::AlreadyExists(AlreadyExists {}));
        }
        
        // User must have at least one role
        if !is_payer && !is_beneficiary && !is_judge {
            return Err(MarketplaceError::InvalidInput(InvalidInput {}));
        }
        
        // Set user data
        user.user_address.set(sender);
        user.balance.set(U256::ZERO);
        user.reputation_as_user.set(I8::ZERO);
        user.reputation_as_judge.set(I8::ZERO);
        user.is_payer.set(is_payer);
        user.is_beneficiary.set(is_beneficiary);
        user.is_judge.set(is_judge);
        user.deals_count.set(U256::ZERO);
        
        evm::log(UserRegistered {
            user: sender,
            is_payer,
            is_beneficiary,
            is_judge,
        });
        
        Ok(())
    }
    
    /// Add additional roles to an existing user
    pub fn add_role(
        &mut self,
        is_payer: bool,
        is_beneficiary: bool,
        is_judge: bool,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let mut user = self.users.setter(sender);
        
        // Check if user is registered
        if user.user_address.get() != sender {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // At least one role must be true
        if !is_payer && !is_beneficiary && !is_judge {
            return Err(MarketplaceError::InvalidInput(InvalidInput {}));
        }
        
        // Set roles
        if is_payer {
            user.is_payer.set(true);
        }
        if is_beneficiary {
            user.is_beneficiary.set(true);
        }
        if is_judge {
            user.is_judge.set(true);
        }
        
        evm::log(UserRegistered {
            user: sender,
            is_payer,
            is_beneficiary,
            is_judge,
        });
        
        Ok(())
    }
    
    /// Create a new deal
    pub fn create_deal(
        &mut self,
        payer: Address,
        amount: U256,
        duration: u64,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        
        // Validate inputs
        if amount == U256::ZERO {
            return Err(MarketplaceError::InvalidInput(InvalidInput {}));
        }
        if payer == Address::ZERO {
            return Err(MarketplaceError::InvalidInput(InvalidInput {}));
        }
        
        // Check user roles
        let sender_user = self.users.get(sender);
        if !sender_user.is_beneficiary.get() {
            return Err(MarketplaceError::InvalidState(InvalidState {}));
        }
        
        let payer_user = self.users.get(payer);
        if !payer_user.is_payer.get() {
            return Err(MarketplaceError::InvalidState(InvalidState {}));
        }
        
        // Get current deal ID
        let deal_id = self.deal_id_counter.get();
        
        // Create deal
        let mut deal = self.deals.setter(U256::from(deal_id));
        deal.deal_id.set(U64::from(deal_id));
        deal.payer.set(payer);
        deal.beneficiary.set(sender);
        deal.amount.set(amount);
        deal.duration.set(U64::from(duration));
        deal.started_at.set(U256::ZERO);
        deal.accepted.set(false);
        deal.disputed.set(false);
        
        let deal_id_u64 = u64::from_le_bytes(deal_id.to_le_bytes());
        evm::log(DealCreated {
            deal_id: deal_id_u64,
            payer,
            beneficiary: sender,
            amount,
        });
        
        // Increment counter
        let current_counter = self.deal_id_counter.get();
        self.deal_id_counter.set(current_counter + U64::from(1));
        
        Ok(())
    }
    
    /// Update deal amount (only before acceptance)
    pub fn update_deal_amount(
        &mut self,
        deal_id: u64,
        new_amount: U256,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let mut deal = self.deals.setter(U256::from(deal_id));
        
        // Check deal exists
        if deal.amount.get() == U256::ZERO {
            return Err(MarketplaceError::NotFound(NotFound {}));
        }
        
        // Only payer can update
        if sender != deal.payer.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // Check not accepted
        if deal.accepted.get() {
            return Err(MarketplaceError::AlreadyExists(AlreadyExists {}));
        }
        
        // Validate amount
        if new_amount == U256::ZERO {
            return Err(MarketplaceError::InvalidInput(InvalidInput {}));
        }
        
        deal.amount.set(new_amount);
        
        evm::log(DealAmountUpdated {
            deal_id,
            new_amount,
        });
        
        Ok(())
    }
    
    /// Update deal duration (only before acceptance)
    pub fn update_deal_duration(
        &mut self,
        deal_id: u64,
        new_duration: u16,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let mut deal = self.deals.setter(U256::from(deal_id));
        
        // Check deal exists
        if deal.amount.get() == U256::ZERO {
            return Err(MarketplaceError::NotFound(NotFound {}));
        }
        
        // Only payer can update
        if sender != deal.payer.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // Check not accepted
        if deal.accepted.get() {
            return Err(MarketplaceError::AlreadyExists(AlreadyExists {}));
        }
        
        // Validate duration
        if new_duration == 0 {
            return Err(MarketplaceError::InvalidInput(InvalidInput {}));
        }
        
        deal.duration.set(U64::from(new_duration));
        
        evm::log(DealDurationUpdated {
            deal_id,
            new_duration,
        });
        
        Ok(())
    }
    
    /// Accept a deal and transfer funds to contract
    pub fn accept_deal(&mut self, deal_id: u64) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let mut deal = self.deals.setter(U256::from(deal_id));
        
        // Check deal exists
        if deal.amount.get() == U256::ZERO {
            return Err(MarketplaceError::NotFound(NotFound {}));
        }
        
        // Only payer can accept
        if sender != deal.payer.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // Check not already accepted
        if deal.accepted.get() {
            return Err(MarketplaceError::AlreadyExists(AlreadyExists {}));
        }
        
        let amount = deal.amount.get();
        let usdc = self.usdc_token.get();
        
        // Mark as accepted
        deal.accepted.set(true);
        deal.started_at.set(U256::from(block::timestamp()));
        
        // Transfer USDC from payer to contract
        let token = IERC20::new(usdc);
        let call = Call::new_in(self);
        let success = token.transfer_from(call, sender, contract::address(), amount)?;
        
        if !success {
            return Err(MarketplaceError::CallFailed(CallFailed {}));
        }
        
        evm::log(DealAccepted { deal_id });
        
        Ok(())
    }
    
    /// Reject a deal (only before acceptance)
    pub fn reject_deal(&mut self, deal_id: u64) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let deal = self.deals.get(U256::from(deal_id));
        
        // Check deal exists
        if deal.amount.get() == U256::ZERO {
            return Err(MarketplaceError::NotFound(NotFound {}));
        }
        
        // Only payer can reject
        if sender != deal.payer.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // Check not accepted
        if deal.accepted.get() {
            return Err(MarketplaceError::AlreadyExists(AlreadyExists {}));
        }
        
        // Delete deal (reset to default values)
        let mut deal_mut = self.deals.setter(U256::from(deal_id));
        deal_mut.deal_id.set(U64::ZERO);
        deal_mut.payer.set(Address::ZERO);
        deal_mut.beneficiary.set(Address::ZERO);
        deal_mut.amount.set(U256::ZERO);
        deal_mut.duration.set(U64::ZERO);
        deal_mut.started_at.set(U256::ZERO);
        deal_mut.accepted.set(false);
        deal_mut.disputed.set(false);
        
        evm::log(DealRejected { deal_id });
        
        Ok(())
    }
    
    /// Finish a deal and release funds to beneficiary
    pub fn finish_deal(&mut self, deal_id: u64) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let deal = self.deals.get(U256::from(deal_id));
        
        // Check deal exists
        if deal.amount.get() == U256::ZERO {
            return Err(MarketplaceError::NotFound(NotFound {}));
        }
        
        // Only payer can finish
        if sender != deal.payer.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // Check deal is accepted
        if !deal.accepted.get() {
            return Err(MarketplaceError::InvalidState(InvalidState {}));
        }
        
        // Check not disputed
        if deal.disputed.get() {
            return Err(MarketplaceError::InvalidState(InvalidState {}));
        }
        
        let amount = deal.amount.get();
        let beneficiary = deal.beneficiary.get();
        let fee_percent = self.fee_percent.get();
        
        // Calculate fee
        let fee = amount * U256::from(fee_percent) / U256::from(100u64);
        let payout = amount - fee;
        
        // Update beneficiary balance
        let mut beneficiary_user = self.users.setter(beneficiary);
        let current_balance = beneficiary_user.balance.get();
        beneficiary_user.balance.set(current_balance + payout);
        
        // Delete deal
        let mut deal_mut = self.deals.setter(U256::from(deal_id));
        deal_mut.deal_id.set(U64::ZERO);
        deal_mut.payer.set(Address::ZERO);
        deal_mut.beneficiary.set(Address::ZERO);
        deal_mut.amount.set(U256::ZERO);
        deal_mut.duration.set(U64::ZERO);
        deal_mut.started_at.set(U256::ZERO);
        deal_mut.accepted.set(false);
        deal_mut.disputed.set(false);
        
        evm::log(DealFinalized { deal_id });
        
        Ok(())
    }
    
    /// Request payment after deal duration has passed
    pub fn request_deal_payment(&mut self, deal_id: u64) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let deal = self.deals.get(U256::from(deal_id));
        
        // Check deal exists
        if deal.amount.get() == U256::ZERO {
            return Err(MarketplaceError::NotFound(NotFound {}));
        }
        
        // Only beneficiary can request payment
        if sender != deal.beneficiary.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // Check deal is accepted
        if !deal.accepted.get() {
            return Err(MarketplaceError::InvalidState(InvalidState {}));
        }
        
        // Check not disputed
        if deal.disputed.get() {
            return Err(MarketplaceError::InvalidState(InvalidState {}));
        }
        
        // Check duration + 1 week has passed
        let started_at = deal.started_at.get();
        let duration = U256::from(deal.duration.get());
        let required_time = started_at + (duration * ONE_DAY) + ONE_WEEK;
        let current_time = U256::from(block::timestamp());
        
        if current_time < required_time {
            return Err(MarketplaceError::InvalidState(InvalidState {}));
        }
        
        let amount = deal.amount.get();
        let beneficiary = deal.beneficiary.get();
        let fee_percent = self.fee_percent.get();
        
        // Calculate fee
        let fee = amount * U256::from(fee_percent) / U256::from(100u64);
        let payout = (amount - fee) * U256::from(10u64.pow(USDC_DECIMALS as u32));
        
        // Update beneficiary balance
        let mut beneficiary_user = self.users.setter(beneficiary);
        let current_balance = beneficiary_user.balance.get();
        beneficiary_user.balance.set(current_balance + payout);
        
        // Delete deal
        let mut deal_mut = self.deals.setter(U256::from(deal_id));
        deal_mut.deal_id.set(U64::ZERO);
        deal_mut.payer.set(Address::ZERO);
        deal_mut.beneficiary.set(Address::ZERO);
        deal_mut.amount.set(U256::ZERO);
        deal_mut.duration.set(U64::ZERO);
        deal_mut.started_at.set(U256::ZERO);
        deal_mut.accepted.set(false);
        deal_mut.disputed.set(false);
        
        evm::log(DealFinalized { deal_id });
        
        Ok(())
    }
    
    /// Request a dispute for a deal
    pub fn request_dispute(
        &mut self,
        deal_id: u64,
        proof: String,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        
        // Validate deal first (using immutable borrow)
        {
            let deal = self.deals.get(U256::from(deal_id));
            
            // Check deal exists
            if deal.amount.get() == U256::ZERO {
                return Err(MarketplaceError::NotFound(NotFound {}));
            }
            
            // Only payer can request dispute
            if sender != deal.payer.get() {
                return Err(MarketplaceError::Unauthorized(Unauthorized {}));
            }
            
            // Check deal is accepted
            if !deal.accepted.get() {
                return Err(MarketplaceError::InvalidState(InvalidState {}));
            }
            
            // Check not already disputed
            if deal.disputed.get() {
                return Err(MarketplaceError::AlreadyExists(AlreadyExists {}));
            }
        }
        
        let usdc = self.usdc_token.get();
        let protocol_addr = self.protocol.get();
        
        // Transfer dispute fee (50 USDC) to protocol
        let dispute_fee = U256::from(50u64) * U256::from(10u64.pow(USDC_DECIMALS as u32));
        let token = IERC20::new(usdc);
        let call = Call::new_in(self);
        let success = token.transfer_from(call, sender, protocol_addr, dispute_fee)?;
        
        if !success {
            return Err(MarketplaceError::CallFailed(CallFailed {}));
        }
        
        // Mark deal as disputed
        let mut deal = self.deals.setter(U256::from(deal_id));
        deal.disputed.set(true);
        drop(deal); // Explicitly drop to release borrow
        
        // Call protocol to create dispute
        let protocol = IProtocol::new(protocol_addr);
        let call2 = Call::new_in(self);
        protocol.create_dispute(call2, deal_id, sender, proof)?;
        
        evm::log(DisputeCreated {
            deal_id,
            requester: sender,
        });
        
        Ok(())
    }
    
    /// Add evidence for a dispute (payer side)
    pub fn add_dispute_evidence_for_payer(
        &mut self,
        dispute_id: u64,
        proof: String,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let dispute = self.disputes.get(U64::from(dispute_id));
        
        // Check dispute exists
        if dispute.deal_id.get() == U64::ZERO {
            return Err(MarketplaceError::NotFound(NotFound {}));
        }
        
        // Only requester can add evidence
        if sender != dispute.requester.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // Proof cannot be empty
        if proof.is_empty() {
            return Err(MarketplaceError::InvalidInput(InvalidInput {}));
        }
        
        // Call protocol to update dispute
        let protocol_addr = self.protocol.get();
        let protocol = IProtocol::new(protocol_addr);
        let call = Call::new_in(self);
        protocol.update_dispute_for_payer(call, dispute_id, sender, proof)?;
        
        Ok(())
    }
    
    /// Add evidence for a dispute (beneficiary side)
    pub fn add_dispute_evidence_for_beneficiary(
        &mut self,
        dispute_id: u64,
        proof: String,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let dispute = self.disputes.get(U64::from(dispute_id));
        
        // Check dispute exists
        if dispute.deal_id.get() == U64::ZERO {
            return Err(MarketplaceError::NotFound(NotFound {}));
        }
        
        // Get deal to verify beneficiary
        let deal_id = dispute.deal_id.get();
        let deal = self.deals.get(U256::from(deal_id));
        
        // Only beneficiary can add evidence
        if sender != deal.beneficiary.get() {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        // Proof cannot be empty
        if proof.is_empty() {
            return Err(MarketplaceError::InvalidInput(InvalidInput {}));
        }
        
        // Call protocol to update dispute
        let protocol_addr = self.protocol.get();
        let protocol = IProtocol::new(protocol_addr);
        let call = Call::new_in(self);
        protocol.update_dispute_for_beneficiary(call, dispute_id, sender, proof)?;
        
        Ok(())
    }
    
    /// Apply the result of a resolved dispute
    pub fn apply_dispute_result(
        &mut self,
        dispute_id: u64,
        deal_id: u64,
    ) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        
        // Validate and get values (using immutable borrows)
        let (amount, fee_percent, requester, beneficiary) = {
            let dispute = self.disputes.get(U64::from(dispute_id));
            
            // Check dispute exists
            if dispute.deal_id.get() == U64::ZERO {
                return Err(MarketplaceError::NotFound(NotFound {}));
            }
            
            let deal = self.deals.get(U256::from(deal_id));
            
            // Only involved parties can execute
            if sender != dispute.requester.get() && sender != deal.beneficiary.get() {
                return Err(MarketplaceError::Unauthorized(Unauthorized {}));
            }
            
            (deal.amount.get(), self.fee_percent.get(), dispute.requester.get(), deal.beneficiary.get())
        };
        
        // Get dispute result from protocol
        let protocol_addr = self.protocol.get();
        let protocol = IProtocol::new(protocol_addr);
        let call = Call::new_in(self);
        let winner = protocol.execute_dispute_result(call, dispute_id)?;
        
        // Calculate payout
        let fee = amount * U256::from(fee_percent) / U256::from(100u64);
        let payout = amount - fee;
        
        // Determine winner address
        let winner_address = if winner {
            requester
        } else {
            beneficiary
        };
        
        // Update winner balance
        let mut winner_user = self.users.setter(winner_address);
        let current_balance = winner_user.balance.get();
        winner_user.balance.set(current_balance + payout);
        
        // Delete deal
        let mut deal_mut = self.deals.setter(U256::from(deal_id));
        deal_mut.deal_id.set(U64::ZERO);
        deal_mut.payer.set(Address::ZERO);
        deal_mut.beneficiary.set(Address::ZERO);
        deal_mut.amount.set(U256::ZERO);
        deal_mut.duration.set(U64::ZERO);
        deal_mut.started_at.set(U256::ZERO);
        deal_mut.accepted.set(false);
        deal_mut.disputed.set(false);
        
        // Delete dispute
        let mut dispute_mut = self.disputes.setter(U64::from(dispute_id));
        dispute_mut.deal_id.set(U64::ZERO);
        dispute_mut.requester.set(Address::ZERO);
        dispute_mut.is_open.set(false);
        dispute_mut.waiting_for_judges.set(false);
        
        evm::log(DisputeResolved {
            dispute_id,
            winner: winner_address,
        });
        
        Ok(())
    }
    
    /// Withdraw user balance
    pub fn withdraw(&mut self) -> Result<(), MarketplaceError> {
        let sender = msg::sender();
        let mut user = self.users.setter(sender);
        
        // Check user is registered
        if user.user_address.get() != sender {
            return Err(MarketplaceError::Unauthorized(Unauthorized {}));
        }
        
        let balance = user.balance.get();
        
        // Check sufficient balance
        if balance == U256::ZERO {
            return Err(MarketplaceError::InsufficientBalance(InsufficientBalance {}));
        }
        
        // Reset balance before transfer (reentrancy protection)
        user.balance.set(U256::ZERO);
        
        // Transfer USDC to user
        let usdc = self.usdc_token.get();
        let token = IERC20::new(usdc);
        let call = Call::new_in(self);
        let success = token.transfer(call, sender, balance)?;
        
        if !success {
            return Err(MarketplaceError::CallFailed(CallFailed {}));
        }
        
        evm::log(UserWithdrew {
            user: sender,
            amount: balance,
        });
        
        Ok(())
    }
    
    // ====================================
    //        VIEW FUNCTIONS          
    // ====================================
    
    /// Get protocol address
    pub fn protocol_address(&self) -> Address {
        self.protocol.get()
    }
    
    /// Get deal ID counter
    pub fn deal_id_counter(&self) -> u64 {
        u64::from_le_bytes(self.deal_id_counter.get().to_le_bytes())
    }
    
    /// Get user info
    pub fn get_user(&self, user_address: Address) -> (Address, U256, i8, i8, bool, bool, bool) {
        let user = self.users.get(user_address);
        (
            user.user_address.get(),
            user.balance.get(),
            i8::from_le_bytes(user.reputation_as_user.get().to_le_bytes()),
            i8::from_le_bytes(user.reputation_as_judge.get().to_le_bytes()),
            user.is_payer.get(),
            user.is_beneficiary.get(),
            user.is_judge.get(),
        )
    }
    
    /// Get deal info
    pub fn get_deal(&self, deal_id: u64) -> (u64, Address, Address, U256, U256, u64, bool, bool) {
        let deal = self.deals.get(U256::from(deal_id));
        (
            u64::from_le_bytes(deal.deal_id.get().to_le_bytes()),
            deal.payer.get(),
            deal.beneficiary.get(),
            deal.amount.get(),
            deal.started_at.get(),
            u64::from_le_bytes(deal.duration.get().to_le_bytes()),
            deal.accepted.get(),
            deal.disputed.get(),
        )
    }
    
    /// Get dispute info
    pub fn get_dispute(&self, dispute_id: u64) -> (u64, Address, bool, bool) {
        let dispute = self.disputes.get(U64::from(dispute_id));
        (
            u64::from_le_bytes(dispute.deal_id.get().to_le_bytes()),
            dispute.requester.get(),
            dispute.is_open.get(),
            dispute.waiting_for_judges.get(),
        )
    }
}
