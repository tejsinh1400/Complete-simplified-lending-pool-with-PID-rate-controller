// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IPriceOracle {
    function getETHPrice() external view returns (uint256);
}

contract LendingPool {

    IERC20 public immutable usdc;
    IERC20 public immutable weth;

    IPriceOracle public immutable priceOracle;
    uint256 public constant LTV = 75; // 75% Loan to value ratio

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debts;

    uint256 public totalDeposits;
    uint256 public totalBorrowed;

    uint256 public borrowAPR = 5; // 5% APR
    uint256 public targetUtilization = 80; // 80% target utilization

    int256 public integral;
    int256 public previousError;

    int256 public kp = 2; // proportional gain
    int256 public ki = 1; // integral gain 
    int256 public kd = 1; // derivative gain 

    uint256 public MAX_RATE_CHANGE = 25; // 0.25% max change per APR update

    constructor(address _usdc, address _weth, address _priceOracle) {
        usdc = IERC20(_usdc);
        weth = IERC20(_weth);
        priceOracle = IPriceOracle(_priceOracle);
    }

    function depositUSDC(uint256 _amount) external {
        
        require(_amount > 0, 'Amount must be greater than 0');

        usdc.transferFrom(msg.sender, address(this), _amount);

        deposits[msg.sender] += _amount;
        totalDeposits += _amount;
    }

    function depositWETH(uint256 _amount) external {
        require (_amount > 0, 'Amount must be greater than 0');

        weth.transferFrom(msg.sender, address(this), _amount);
        collateral[msg.sender] += _amount;
        
    }

    function collateralValue(address _user) public view returns(uint256){
        uint256 wethPrice = priceOracle.getETHPrice();
        return collateral[_user] * wethPrice/ 1e18;
    }

    function MaxBorrowable(address _user) public view returns(uint256) {
        return collateralValue(_user) * LTV / 100;
    }

    function borrow(uint256 _amount) external{
        require(_amount > 0, 'Amount must be greater than 0');

        uint256 newDebt = debts[msg.sender] + _amount;

        require(newDebt <= MaxBorrowable(msg.sender), 'Borrow limit exceeded');
        require(usdc.balanceOf(address(this)) >= _amount, 'Insufficient balance');

        debts[msg.sender] = newDebt;
        totalBorrowed += _amount;

        usdc.transfer(msg.sender, _amount);
        
    }

    function repay(uint256 _amount) external {
        require(_amount > 0, 'Amount must be greater than 0');
        usdc.transferFrom(msg.sender, address(this), _amount);

        require(_amount <= debts[msg.sender], 'Too much repayment');
        debts[msg.sender] -= _amount;
        totalBorrowed -= _amount;
    }

    function utilizationRate() public view returns(uint256){
        if(totalDeposits == 0){
            return 0;
             } else{
                return totalBorrowed * 1e18 / totalDeposits;
             }
    }

    function rebalanceRate() external {
    uint256 currentUtilization = utilizationRate();

    int256 utilizationError =
        int256(currentUtilization) -
        int256(targetUtilization);

    integral += utilizationError;

    int256 derivative =
        utilizationError - previousError;

    int256 adjustment =
        (kp * utilizationError) +
        (ki * integral) +
        (kd * derivative);

    previousError = utilizationError;

    uint256 rateChange;

    if (adjustment > 0) {
        require(
            adjustment <= int256(type(uint256).max),
            "Adjustment too large"
        );

        rateChange = uint256(adjustment);

        if (rateChange > MAX_RATE_CHANGE) {
            rateChange = MAX_RATE_CHANGE;
        }

        borrowAPR += rateChange;

    } else {
        int256 positiveAdjustment = -adjustment;

        require(
            positiveAdjustment <= int256(type(uint256).max),
            "Adjustment too large"
        );

        rateChange = uint256(positiveAdjustment);

        if (rateChange > MAX_RATE_CHANGE) {
            rateChange = MAX_RATE_CHANGE;
        }

        if (rateChange > borrowAPR) {
            borrowAPR = 0;
        } else {
            borrowAPR -= rateChange;
        }
    }
}
}