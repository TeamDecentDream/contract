// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NZFToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant TOTAL_SUPPLY = 10_000_000 * (10**18);
    uint256 public constant DEVELOPER_SUPPLY = 1_000_000 * (10**18);
    uint256 public constant INVESTOR_SUPPLY = 9_000_000 * (10**18);
    uint256 public constant MINT_LIMIT_PER_INVESTOR = 20_000 * (10**18);

    // USDT 컨트랙트 주소
    // TestUSDTContractAddress = 0xf7ADDb930777E11b83A5E7494421Ec4C589d0317
    address public developerWallet;
    address public USDTAddress;


    // 개인지갑 별 토큰 발행량
    mapping(address => uint256) public mintedTokens;

    event DeveloperMint(address indexed to, uint256 amount);
    event InvestorMint(address indexed to, uint256 amount);

    modifier onlyDeveloper() {
        require(msg.sender == developerWallet, "Not authorized");
        _;
    }

    modifier canMint(uint256 amount) {
        require(totalSupply() + amount <= TOTAL_SUPPLY, "Exceeds total supply");
        _;
    }

    // 컨트랙트 배포와 동시에 개발자 물량 발행
    constructor(address _developerWallet, address _USDTAddress) ERC20("NZF Token", "NZF") Ownable(_developerWallet) {
        developerWallet = _developerWallet;
        USDTAddress = _USDTAddress;
        _mint(developerWallet, DEVELOPER_SUPPLY);
    }

    // 투자자 민팅 함수
    function mintInvestor(uint256 amount) external canMint(amount) {
        require(amount <= MINT_LIMIT_PER_INVESTOR, "Exceeds mint limit per investor");
        require(mintedTokens[msg.sender] + amount <= MINT_LIMIT_PER_INVESTOR, "Exceeds mint limit for the investor");
        require(IERC20(USDTAddress).allowance(msg.sender, address(this)) >= amount, "You must approve the contract to access your USDT");
        
        IERC20(USDTAddress).safeTransferFrom(msg.sender, address(this), amount);
        
        _mint(msg.sender, amount);
        mintedTokens[msg.sender] += amount;

        emit InvestorMint(msg.sender, amount);
    }

    // 개발자 USDT 회수 함수
    function withdraw() external onlyDeveloper {
        uint256 contractBalance = IERC20(USDTAddress).balanceOf(address(this));
        require(contractBalance > 0, "No tokens to withdraw");

        IERC20(USDTAddress).transfer(developerWallet, contractBalance);
    }
}
