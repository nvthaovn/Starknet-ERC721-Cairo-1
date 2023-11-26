# Starknet ERC721 NFT Smart Contract
ERC721 smart contract template for Starknet blockchain using Cairo language version 1.x. Supports configuring metadata files sequentially by NFT's ID
# Compatibility ✨
- NFTs market: Element market, Unframed, Pyramid, Flexing...
- Wallets and explorers: ArgentX, Braavos, Starkscan...
- Cairo version: Cairo 1

# Disclaimer ✨
This is just a test sample. It may pose undiscovered security risks. If you want to use it in your products, you should review it carefully.

# How to Deploy sample NFT

### Requirements
- Scarb v2.3+ | A buildtool used to compile Cairo files (build).
- Starkli v0.1+ | Command line tool to interact with the Starknet blockchain, helping you deploy smart contracts to the Starknet network

Docs: [Guide to setup Starkli and Scrab](https://docs.starknet.io/documentation/quick_start/environment_setup)

### Clone the Project
```sh
git clone https://github.com/nvthaovn/Starknet-ERC721-Cairo-1.git
cd Starknet-ERC721-Cairo-1
```
### Customize your NFT in the file: ./src/ERC721Contract.cairo
All String must be converted to Bytes (Online tool: https://codebeautify.org/string-hex-converter)
```cairo
const NAME: felt252 = 0x4d792044656d6f204e4654;	
const SYMBOL: felt252 = 0x4d444e;	
const BASE_URI_PART_1: felt252 = 0x697066733a2f2f516d505a6e336f5967486f676343643835;
const BASE_URI_PART_2: felt252 = 0x697251685033794d61446139387878683654653550426e53;
const BASE_URI_PART_3: felt252 = 0x61626859722f;
const MAX_SUPPLY: u256 = 9999;
const ADMIN_ADDRESS: felt252 = 0x004203062d78f4481be03c9145022d6a4a71ec0719a07756f79a2384djfk54r;
```
### BASE_URI detail
BASE URI is the root path that we can combine with the NFT id to automatically create a path to the metadata file of each NFT. When the contract's tokenURI() function is called, a path to the token's json file will be automatically generated based on the requested Token id. This method is similar to the nft metadata structure of other popular tools such as: NFT2Me, Zora...
```
TOKEN_URI = BASE_URI+TOKEN_ID+.json 
```
Eg: 
```
ipfs://QmPZn3oYgHogcCd85irQhP3yMaDa98xxh6Te5PBnSabhYr/33.json
https://yourmediaserver.com/45.json
```
You can store media files and data on Web2.0 servers using https or free onchain storage using ipfs services like: https://nft.storage

Metadata file structure: https://docs.opensea.io/docs/metadata-standards

### Build your contract
```sh
scarb build
```
If the build is successful, you will receive a file: ./target/dev/contracts_ERC721Contract.sierra.json
### Declare your contract (Upload contract to Starknet Network)
Default supported network: mainnet, goerli-1 (Starknet testnet)
```sh
starkli declare ./target/dev/contracts_ERC721Contract.sierra.json --network=mainnet --compiler-version=2.1.0
```
After declaring successfully, you will receive the class hash of the contract you just created
### Deploy your Contract
```sh
starkli deploy 0x00000f0df0d0f0d0ffd0ffaaaaaYourContractClassHash --network=mainnet
```

### Done !


## Reference
| Docs | Link |
| ------ | ------ |
| Cairo 1 docs | https://docs.cairo-lang.org |
| Starknet Docs | https://docs.starknet.io |

## License
MIT


**Feel free to share the problems you encounter!**