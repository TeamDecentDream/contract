// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NZFToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    uint256 public constant TOTAL_SUPPLY = 10_000_000 * (10**18);
    uint256 public constant DEVELOPER_SUPPLY = 1_000_000 * (10**18);
    uint256 public constant INVESTOR_SUPPLY = 9_000_000 * (10**18);
    uint256 public constant MINT_LIMIT_PER_INVESTOR = 20_000 * (10**18);

    // USDT 컨트랙트 주소
    // TestUSDTContractAddress = 0xf7ADDb930777E11b83A5E7494421Ec4C589d0317
    address public USDTAddress;
    address public developerWallet;
    uint256 public currentSupply;
    

    // 개인지갑 별 토큰 발행량
    mapping(address => uint256) public mintedTokens;
    
    mapping(uint256 => uint256) public remaingProfit;
    mapping(uint256 => uint256) public profitPerDay;
    mapping(uint256 => uint256) public buyBackTimer;
    mapping(uint256 => bool) public indexSet;

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
    constructor(address _developerWallet, address _USDTAddress)
        ERC20("NZF Token", "NZF")
        Ownable(_developerWallet)
    {
        developerWallet = _developerWallet;
        USDTAddress = _USDTAddress;
        _mint(developerWallet, DEVELOPER_SUPPLY);
    }

    // 투자자 민팅 함수
    function mintInvestor(uint256 amount) external canMint(amount) {
        require(
            amount <= MINT_LIMIT_PER_INVESTOR,
            "Exceeds mint limit per investor"
        );
        require(
            mintedTokens[msg.sender] + amount <= MINT_LIMIT_PER_INVESTOR,
            "Exceeds mint limit for the investor"
        );
        require(
            IERC20(USDTAddress).allowance(msg.sender, address(this)) >= amount,
            "You must approve the contract to access your USDT"
        );

        IERC20(USDTAddress).safeTransferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, amount);
        mintedTokens[msg.sender] += amount;
        currentSupply += amount;

        emit InvestorMint(msg.sender, amount);
    }

    // 개발자 USDT 회수 함수
    function withdraw() external onlyDeveloper {
        uint256 contractBalance = IERC20(USDTAddress).balanceOf(address(this));
        require(contractBalance > 0, "No tokens to withdraw");
        require(currentSupply > TOTAL_SUPPLY, "Not Enough Supply");

        //Factory_addr 0x0227628f3F023bb0B980b67D528571c95c6DaC1c
        // USDT 컨트랙트 주소
        // TestUSDTContractAddress = 0xf7ADDb930777E11b83A5E7494421Ec4C589d0317
        poolInit(
            0x0227628f3F023bb0B980b67D528571c95c6DaC1c,
            address(this),
            0xf7ADDb930777E11b83A5E7494421Ec4C589d0317,
            500
        );
        IERC20(USDTAddress).transfer(developerWallet, contractBalance);
    }

    // Factory에 Pool & init생성.
    function poolInit(
        address factory_addr,
        address token0,
        address token1,
        uint24 fee
    ) internal {
        (bool success, bytes memory poolAddress) = factory_addr.call(
            abi.encodeWithSignature(
                "createPool(address,address,uint24)",
                token0,
                token1,
                fee
            )
        );
        require(success, "Failed to find Factory");
        address poolAddress_ = bytesToAddress(poolAddress);
        (success, ) = address(poolAddress_).call(
            abi.encodeWithSignature("initailize(uint160)", 500000)
        );
        require(success, "Failed to Pool initialize");

        MintParams memory params;
        params.token0 = token0;
        params.token1 = token1;
        params.fee = fee;
        params.lowerTick = -887220;
        params.upperTick = 887220;
        params.amount0Desired = 500000 * (10**18);
        params.amount1Desired = 500000 * (10**18);
        params.amount0Min = 0;
        params.amount1Min = 0;

        (success, ) = address(poolAddress_).call(
            abi.encodeWithSignature(
                "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256))",
                params
            )
        );
        require(success, "Failed to Mint");
    }

    
    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }

    function setProfit(uint256 amount, uint256 index) public onlyDeveloper {
        require(!indexSet[index], "Index already set");
        indexSet[index] = true;
        remainingProfit[index] = amount;
        profitPerDay[index] = amount / 200;
        buyBackTimer[index] = block.timestamp + 200 days;
    }

    function buyBack(address pool, uint256 index) public onlyDeveloper {
        require(remaingProfit[index] > 0, "Remain Amount must be greater than zero");
        (bool success, ) = pool.call(abi.encodeWithSignature(
            "swap(address,bool,uint256,uint160,bytes)",
            msg.sender,
            false,
            0,
            0,
            new bytes(0))
        );
        require(success, "Failed to Mint");
    }

}
