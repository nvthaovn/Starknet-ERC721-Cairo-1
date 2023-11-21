#[starknet::contract]
mod ERC721Contract {
    ////////////////////////////////
    // library imports
    ////////////////////////////////
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::contract_address_to_felt252;
    use zeroable::Zeroable;
    use traits::Into;
    use traits::TryInto;
    use nullable::{nullable_from_box, match_nullable, FromNullableResult};
    
    //####### ERC721 Cairo 1 Source ########
    
    //# Default Const - Change it to your NFT metadatas #
    // Note: All your string (const) must be convert into bytes. (online tool: https://codebeautify.org/string-hex-converter)
    
    // Your NFT's Name as Bytes. eg: "My Demo NFT" -> 0x4d792044656d6f204e4654
    const NAME: felt252 = 0x4d792044656d6f204e4654;    
    
    // Your NFT's Token Symbol as Bytes. eg: "MDN" -> 0x4d444e
    const SYMBOL: felt252 = 0x4d444e;    
    
    // BASE URI is the root path that we can combine with the NFT id to automatically create a path to the metadata file of each NFT.
    // You can store media files and data on Web2.0 servers using https or free onchain storage using ipfs services like https://nft.storage
    // eg: ipfs://BASE_URI/33.json or https://yourmediaserver.com/33.json
    // Format of metadata file: https://docs.opensea.io/docs/metadata-standards
    // Our BASE URI is fully compatible with IPFS metadata of nfts2me or Zora...
    // (BASE URI must be divided into 3 parts because Cairo 1 does not support long String by default)
    // Eg: ipfs://QmPZn3oYgHogcCd85irQhP3yMaDa98xxh6Te5PBnSabhYr/   -> 0x697066733a2f2f516d505a6e336f5967486f676343643835697251685033794d61446139387878683654653550426e5361626859722f
    const BASE_URI_PART_1: felt252 = 0x697066733a2f2f516d505a6e336f5967486f676343643835;
    const BASE_URI_PART_2: felt252 = 0x697251685033794d61446139387878683654653550426e53;
    const BASE_URI_PART_3: felt252 = 0x61626859722f;
    
    // Total number of NFTs that can be minted
    const MAX_SUPPLY: u256 = 9999;
    
    // Only Admin can use administrative functions
    const ADMIN_ADDRESS: felt252 = 0x001356F388A5E37015FEA32329aCF6cEa266139FA745A1123d37ab8A92c025A5;
    
    const VERSION_CODE: u256 = 202311150001001; /// YYYYMMDD000NONCE
    //# Const Default Init End #
    
    
    // ERC 165 interface codes
    const INTERFACE_ERC165: felt252 = 0x01ffc9a7;
    const INTERFACE_ERC721: felt252 = 0x80ac58cd;
    const INTERFACE_ERC721_METADATA: felt252 = 0x5b5e139f;
    const INTERFACE_ERC721_RECEIVER: felt252 = 0x150b7a02; 
    
    ////////////////////////////////
    // storage variables
    ////////////////////////////////
    #[storage]
    struct Storage {
        owners: LegacyMap::<u256, ContractAddress>,
        balances: LegacyMap::<ContractAddress, u256>,
        token_approvals: LegacyMap::<u256, ContractAddress>,
        operator_approvals: LegacyMap::<(ContractAddress, ContractAddress), bool>,
        count: u256, //Total number of NFTs minted
    }

    // ####################EVENTS#################### //
    // Events play a crucial role in the creation of smart contracts. Take, for instance, the Non-Fungible Tokens (NFTs) minted on Starknet. 
    // All of these are indexed and stored in a database, then displayed to users through the use of these events. 
    // Neglecting to include an event within your NFT contract could lead to a bad user experience. This is because users may not see their NFTs 
    // appear in their wallets (wallets use these indexers to display a user's NFTs).
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Approval: Approval,
        Transfer: Transfer,
        ApprovalForAll: ApprovalForAll
    }

    ////////////////////////////////
    // Approval event emitted on token approval
    ////////////////////////////////
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        to: ContractAddress,
        token_id: u256
    }

    ////////////////////////////////
    // Transfer event emitted on token transfer
    ////////////////////////////////
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256
    }

    ////////////////////////////////
    // ApprovalForAll event emitted on approval for operators
    ////////////////////////////////
    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        owner: ContractAddress,
        operator: ContractAddress,
        approved: bool
    }


    ////////////////////////////////
    // Constructor - initialized on deployment
    // This function will be called only once when deploying the contract
    // Note: get_caller_address() in this function will not return your address because we will deploy the contract through an intermediate contract
    ////////////////////////////////
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.initConfig();
    }
    
    #[generate_trait]
    impl ConfigImpl of ConfigTrait {
        fn initConfig(ref self: ContractState){
            //Configure the contract based on parameters when deploying the contract if needed
        }
    }

    // #################### ERC721 PUBLIC FUNCTION #################### //
    // generate_trait allow to use vitual Trait like IERC721Trait without declared before
    #[external(v0)]
    #[generate_trait]
    impl IERC721Impl of IERC721Trait {
        ////#### Read Functions ###////
        
        // EPI-721 https://eips.ethereum.org/EIPS/eip-721
        //***** ERC721 Metadata *****//
        
        // get_name function returns NFT's name
        fn name(self: @ContractState) -> felt252 {
            NAME
        }

        // get_symbol function returns NFT's token symbol
        fn symbol(self: @ContractState) -> felt252 {
            SYMBOL
        }
        
        // get tokenURI link to json file metadata
        // jsonMetaFile = BaseURI + TOKEN_ID + .json
        fn tokenURI(self: @ContractState, token_id: u256) -> Array<felt252> {
            let tokenFile: felt252 = token_id.try_into().unwrap();
            let mut link = self._getBaseURI(); //BaseURI
            //# Convert int id into Cairo ShortString(bytes) #
            // revert number   12345 -> 54321, 1000 -> 0001
            let mut revNumber: u256 = 0;
            let mut currentInt: u256 = token_id * 10 + 1;
            loop {
                revNumber = revNumber*10 + currentInt % 10;
                currentInt = currentInt / 10_u256;
                if currentInt < 1 {
                    break;
                };
            };
            //split chart
            loop {
                let lastChar: u256 = revNumber % 10_u256;
                link.append(self._intToChar(lastChar));  // BaseURI + TOKEN_ID
                revNumber = revNumber / 10_u256;
                if revNumber < 2 {   //~ = 1
                    break;
                };
            };
            link.append(0x2e6a736f6e); // BaseURI + TOKEN_ID + .json
            link
        }
        // Compatibility
        fn token_uri(self: @ContractState, token_id: u256) -> Array<felt252> {
            self.tokenURI(token_id)
        }
        
        // Contract-level metadata - https://docs.opensea.io/docs/contract-level-metadata
        // NFT marketplaces use contractURI json file to get information about your collection
        fn contractURI(self: @ContractState) -> Array<felt252>{
            //In this example we use the json file of the first NFT in the collection, but you should customize it to return the correct file
            self.tokenURI(1)
        }
        // Compatibility
        fn contract_uri(self: @ContractState) -> Array<felt252>{
            self.contractURI()
        }
        
        // get maxSupply
        fn maxSupply(self: @ContractState) -> u256{
            MAX_SUPPLY
        }
        
        //***** ERC721 Enumerable *****//
        
        // get current total nfts minted
        fn totalSupply(self: @ContractState) -> u256{
            self.count.read()
        }
        // Compatibility
        fn total_supply(self: @ContractState) -> u256{
            self.totalSupply()
        }
        
        //*****  ERC-2981 EIP165 - NFT Royalty Standard *****//
        
        // get - check supportsInterface
        fn supportsInterface(self: @ContractState, interfaceID: felt252 ) -> bool {
            interfaceID == INTERFACE_ERC165 ||
            interfaceID == INTERFACE_ERC721 ||
            interfaceID == INTERFACE_ERC721_METADATA
        }
        // Compatibility
        fn supports_interface(self: @ContractState, interfaceID: felt252 ) -> bool {
            self.supportsInterface(interfaceID)
        }
        
        //***** ERC721 *****//
        
        // get balance_of function returns token balance
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            assert(account.is_non_zero(), 'ERC721: address zero');
            self.balances.read(account)
        }
        // Compatibility
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balanceOf(account)
        }

        // get owner_of function returns owner of token_id
        fn ownerOf(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.owners.read(token_id);
            assert(owner.is_non_zero(), 'ERC721: invalid token ID');
            owner
        }
        // Compatibility
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self.ownerOf(token_id)
        }

        // get_approved function returns approved address for a token
        fn getApproved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), 'ERC721: invalid token ID');
            self.token_approvals.read(token_id)
        }
        // Compatibility
        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            self.getApproved(token_id)
        }

        // get is_approved_for_all function returns approved operator for a token
        fn isApprovedForAll(self: @ContractState, owner: ContractAddress, operator: ContractAddress) -> bool {
            self.operator_approvals.read((owner, operator))
        }
        // Compatibility
        fn is_approved_for_all(self: @ContractState, owner: ContractAddress, operator: ContractAddress) -> bool {
            self.isApprovedForAll(owner, operator)
        }

        ////#### Write Functions ###////
        
        // set approve function approves an address to spend a token
        ////////////////////////////////
        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self.ownerOf(token_id);
            assert(to != owner, 'Approval to current owner');
            assert(get_caller_address() == owner || self.isApprovedForAll(owner, get_caller_address()), 'Not token owner');
            self.token_approvals.write(token_id, to);
            self.emit(
                Approval{ owner: self.ownerOf(token_id), to: to, token_id: token_id }
            );
        }

        // set_approval_for_all function approves an operator to spend all tokens 
        fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
            let owner = get_caller_address();
            assert(owner != operator, 'ERC721: approve to caller');
            self.operator_approvals.write((owner, operator), approved);
            self.emit(
                ApprovalForAll{ owner: owner, operator: operator, approved: approved }
            );
        }
        // Compatibility
        fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
            self.setApprovalForAll(operator,approved)
        }

        // set transfer_from function is used to transfer a token
        fn transferFrom(ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256) {
            assert(self._is_approved_or_owner(get_caller_address(), token_id), 'neither owner nor approved');
            self._transfer(from, to, token_id);
        }
        
        // safe transfer an NFT
        fn safeTransferFrom(ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>) {
            // #Todo - Check that the receiving address is a contract address and that it supports INTERFACE_ERC721_RECEIVER
            self.transferFrom(from,to,token_id)
        }
        // Compatibility
        fn safe_transfer_from(ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>) {
            self.safeTransferFrom(from,to,token_id,data)
        }
        
    }
    
    // #################### ADMIN CONTROL FUNCTIONS #################### //
    #[external(v0)]
    #[generate_trait]
    impl ERC721AdminImpl of ERC721AdminTrait {
        // Airdrop
        fn airdrop(ref self: ContractState, to: ContractAddress, amount: u256){
            self._assert_admin();
            let limit: u256 = 500;
            assert(to.is_non_zero(), 'TO_IS_ZERO_ADDRESS');
            assert(amount<=limit, 'Amount is too much');
            self._assert_mintable(self.count.read()+amount);
            let startID: u256 = self.count.read();
            let mut i: u256 = 1;
            loop {
                if i > amount {
                    break;
                }
                self._safe_mint(to, startID+i);
                i += 1;
            };
            // Increase receiver balance
            let receiver_balance = self.balances.read(to);
            self.balances.write(to, receiver_balance + amount.into());
            
            // Increase total nft
            self.count.write(startID + amount.into());
        }
        // Batch Airdrop - Airdrop to multiple receiving addresses, each receiving 1 NFT
        fn batchAirdrop(ref self: ContractState, addressArr: Array<ContractAddress>){
            self._assert_admin();
            let totalAmount: u32 = addressArr.len();
            let limit: u32 = 200;
            assert(totalAmount<=limit, 'Input is too long');
            self._assert_mintable(self.count.read()+totalAmount.into());
            //Airdrop
            let startID: u256 = self.count.read();
            let mut i: u32 = 0;
            let mut doneCount: u256 = 0;
            loop {
                if i>(totalAmount-1) {
                    break;
                }
                let toAddress: ContractAddress = *addressArr.at(i);
                if(toAddress.is_non_zero()){
                    self._safe_mint(toAddress, startID+doneCount+1);
                    //update user balance
                    let receiver_balance: u256 = self.balances.read(toAddress);
                    self.balances.write(toAddress, receiver_balance + 1);
                    //update done count
                    doneCount = doneCount +1;
                }
                i = i+1;
            };
            // Increase total nft
            self.count.write(startID + doneCount);
        }
    }
    
    // #################### PRIVATE Helper FUNCTION #################### //
    #[generate_trait]
    impl ERC721HelperImpl of ERC721HelperTrait {
        //assert
        // check admin permission 
        fn _assert_admin(self: @ContractState) {
            assert(get_caller_address() == self._felt252ToAddress(ADMIN_ADDRESS), 'Caller not admin')
        }
        // check mintable
        fn _assert_mintable(self: @ContractState, max_token_id: u256) {
            assert(max_token_id <= MAX_SUPPLY, 'Out of collection size');
        }
    
        ////////////////////////////////
        // internal function to check if a token exists
        ////////////////////////////////
        fn _exists(self: @ContractState, token_id: u256) -> bool {
            // check that owner of token is not zero
            self.ownerOf(token_id).is_non_zero()
        }

        ////////////////////////////////
        // _is_approved_or_owner checks if an address is an approved spender or owner
        ////////////////////////////////
        fn _is_approved_or_owner(self: @ContractState, spender: ContractAddress, token_id: u256) -> bool {
            let owner = self.owners.read(token_id);
            spender == owner
                || self.isApprovedForAll(owner, spender) 
                || self.getApproved(token_id) == spender
        }

        ////////////////////////////////
        // internal function that performs the transfer logic
        ////////////////////////////////
        fn _transfer(ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256) {
            // check that from address is equal to owner of token
            assert(from == self.ownerOf(token_id), 'ERC721: Caller is not owner');
            // check that to address is not zero
            assert(to.is_non_zero(), 'ERC721: transfer to 0 address');

            // remove previously made approvals
            self.token_approvals.write(token_id, Zeroable::zero());

            // increase balance of to address, decrease balance of from address
            self.balances.write(from, self.balances.read(from) - 1);
            self.balances.write(to, self.balances.read(to) + 1);

            // update token_id owner
            self.owners.write(token_id, to);

            // emit the Transfer event
            self.emit(
                Transfer{ from: from, to: to, token_id: token_id }
            );
        }
        
        // safe mint - Optimize airdrop fees
        fn _safe_mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            // Update token_id owner
            self.owners.write(token_id, to);

            // emit Transfer event
            self.emit(
                Transfer{ from: Zeroable::zero(), to: to, token_id: token_id }
            );
        }
        
        // get baseURI()
        fn _getBaseURI(self: @ContractState) -> Array<felt252>{
            let mut baseLinkArr = ArrayTrait::new();
            baseLinkArr.append(BASE_URI_PART_1);
            baseLinkArr.append(BASE_URI_PART_2);
            baseLinkArr.append(BASE_URI_PART_3);
            baseLinkArr
        }
    }
    
    // #################### Base Helper FUNCTION #################### //
    #[generate_trait]
    impl BaseHelperImpl of BaseHelperTrait {
        
        // convert int short string .  eg: 1 -> 0x31 
        fn _intToChar(self: @ContractState, input: u256) ->felt252{
            if input == 0 {
                return 0x30;
            }
            else if input == 1{
                return 0x31;
            }
            else if input == 2{
                return 0x32;
            }
            else if input == 3{
                return 0x33;
            }
            else if input == 4{
                return 0x34;
            }
            else if input == 5{
                return 0x35;
            }
            else if input == 6{
                return 0x36;
            }
            else if input == 7{
                return 0x37;
            }
            else if input == 8{
                return 0x38;
            }
            else if input == 9{
                return 0x39;
            }
            0x0
        }
        
        // convert felt252 hex address to Address type
        fn _felt252ToAddress(self: @ContractState, input: felt252) -> ContractAddress{
            input.try_into().unwrap()
        }
    }
    
    // #################### ADMIN CONTROL FUNCTION #################### //
    #[external(v0)]
    #[generate_trait]
    impl ContractImpl of ContractTrait {
        // return version code of contract
        fn versionCode(self: @ContractState) -> u256{
            VERSION_CODE
        }
    }
}