// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Mock Wrapped Ether", "mWETH") {
        _mint(msg.sender, 1_000 * 10 ** decimals());
    }
}