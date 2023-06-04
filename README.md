# The Unfettered - SOULS Contracts
The Unfettered is role-playing video game that offers an unparalleled decentralized play2earn gaming experience on the blockchain. The game features a soulslike genre, developed by Trender Software on the Unreal Engine 5, designed to provide players with an immersive and challenging gaming experience. The mission of The Unfettered is to provide true gaming freedom, and the vision is to create a fair and transparent gaming ecosystem. 

Gaming contracts are under development in a private repo and will be added here after deployment. This repo includes the base contracts of the Unfettered ecosystem. All contracts are deployed on Polygon network.

## [SoulsToken.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/SoulsToken.sol)
The Unfettered Souls (SOULS) ERC-20 token contract of the ecosystem which is deployed to [0xefCFEce12A99d1DbBf6F3264ee97F8C045e97F1f](https://polygonscan.com/address/0xefCFEce12A99d1DbBf6F3264ee97F8C045e97F1f#code). 

## [Managers.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Managers.sol)
All critical transactions in the Unfettered ecosystem require the approval of three out of 5 managers. The Managers contract is responsible for opening new titles for approval, deleting them and performing the transaction when sufficient votes are reached. It is deployed to [0x6de4e34dcAB7Ac63453581EF9e615BeAC72969EB](https://polygonscan.com/address/0x6de4e34dcAB7Ac63453581EF9e615BeAC72969EB)

## [MainVault.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/MainVault.sol)
MainVault is the factory contract of SoulsToken contract and it receives all the minted SOULS tokens after deployment to distribute other vaults which is listed below in according to the [tokenomy](https://www.theunfettered.io/tokenomics.html) table. It is deployed to [0x2d962ABeF7E7033bE52b65c62E0a6B4c3777FCfa](https://polygonscan.com/address/0x2d962ABeF7E7033bE52b65c62E0a6B4c3777FCfa)

## [BotPrevention.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/BotPrevention.sol)
Manages trading start time on DEX and prevents big amount of sells during launch. Deployed to: [0x9B7f679F7b48C6Cc13568996E16356c180205Fe1](https://polygonscan.com/address/0x9B7f679F7b48C6Cc13568996E16356c180205Fe1)

## [Vault.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Vaults/Vault.sol)
Base contract for all vault contracts which stores vesting schedule, releases tokens and allows withdrawal when requested by project admins according to the tokenomy table. 

  - Deployed to [0xCA16943A156ca748ECb667D530Cdf6B6b23d8D66](https://polygonscan.com/address/0xCA16943A156ca748ECb667D530Cdf6B6b23d8D66) as Marketing Vault, 
  -  Deployed to [0x1136365a23f80F3f176e40257858B02889266B73](https://polygonscan.com/address/0x1136365a23f80F3f176e40257858B02889266B73) as Advisoer Vault, 
 -  Deployed to [0xA24Cf6590C6185e70D6be14a6cc1580457577c3B](https://polygonscan.com/address/0xA24Cf6590C6185e70D6be14a6cc1580457577c3B) as Team Vault, 
 -  Deployed to [0xDaa7C91dAaA3aaA5afBe405e9efa356E8F7B9356](https://polygonscan.com/address/0xDaa7C91dAaA3aaA5afBe405e9efa356E8F7B9356) as Treasury Vault.

## [LiquidityVault.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Vaults/LiquidityVault.sol)
Manages liqiudity tokens and allows managers to add liquidity on DEX. Firstly creates liquidity pool with certain amount of liquidity to set DEX initial price during initialization. After that managers can add extra liquidity through this contract. All created LP tokens are transferred to Main Vault and locked for 365 days. Deployed to [0x6267bd8752a981c8AF9DF5B9C97da95DA78A21e3](https://polygonscan.com/address/0x6267bd8752a981c8AF9DF5B9C97da95DA78A21e3).

## [CrowdfundingVault.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Vaults/CrowdfundingVault.sol)
Stores crowdfunding tokens until managers creates claims for crowdfunding investors, then all tokens will be transferred seperate crowdfunding contracts (Seed sale, Strategic sale, Private sale, Public sale and Pass Holder sale). It is deployed to [0xd6e2f1ba77B13Bea13fc93bBeD365314fF75A8b7](https://polygonscan.com/address/0xd6e2f1ba77B13Bea13fc93bBeD365314fF75A8b7).

## [AirdropVault.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Vaults/AirdropVault.sol)
Holds airdrop tokens vesting data and allows managers to transfer tokens to Airdrop contract to create new airdrops and deployed to [0x9832eB499B6332576323F10b901A632d9D25121b](https://polygonscan.com/address/0x9832eB499B6332576323F10b901A632d9D25121b).

## [StakingVault.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Vaults/StakingVault.sol)
Holds staking/farming reward tokens vesting data and allows managers to transfer tokens to Staking contract. Deployed to [0x0f92ed442801e949efFDF9EecE806A43De20F53A](https://polygonscan.com/address/0x0f92ed442801e949efFDF9EecE806A43De20F53A)

## [PlayToEarnVault.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Vaults/PlayToEarnVault.sol)
Holds Play to Earn tokens vesting info and transfers required amount of tokens to WithdrawClaim contract (will be deployed and added here after game launch) during creation of claim data by play to earn service according to the players requests of token withdrawal from game. Deployed to [0xe19Adb977cf82224Da8109aC2656a547F52e6576](https://polygonscan.com/address/0xe19Adb977cf82224Da8109aC2656a547F52e6576)

## [Crowdfunding.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Claimables/Crowdfunding.sol)
Base contract for all crowdfundings. All vesting data added to contracts after deployment and before TGE. Investors can claim their tokens from [crowdfunding claim page](https://crowdfunding.theunfettered.io). Deployment addresses:

- Seed Sale contract: [0x21B731aF8Af5C4065C766c45eb0a820A42b42121](https://polygonscan.com/address/0x21B731aF8Af5C4065C766c45eb0a820A42b42121)
- Strategic Sale contract: [0xc624c0c668a833A9b4d5Ed99784d66C507887378](https://polygonscan.com/address/0xc624c0c668a833A9b4d5Ed99784d66C507887378)
- Private Sale contract: [0xd21A57d4B346698A2F553b984B066C8A3f69624B](https://polygonscan.com/address/0xd21A57d4B346698A2F553b984B066C8A3f69624B)
- Public Sale contract: [0x6405B332641d499fc93937925945512D02629D47](https://polygonscan.com/address/0x6405B332641d499fc93937925945512D02629D47)
- Pass Holder Sale contract: [0x9649f5D5A76905E0ac4e2d61dc80Cf2640B1d80C](https://polygonscan.com/address/0x9649f5D5A76905E0ac4e2d61dc80Cf2640B1d80C)

NOTE: All public sale tokens are transferred to launchpads and claims will be in their page. 

## [Staking.sol](https://github.com/unfetteredgame/Unfettered-Souls-Contracts/blob/main/contracts/Claimables/Staking.sol) 
Will be deployed soon.

