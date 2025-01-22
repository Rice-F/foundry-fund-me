// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    // 标签化地址生成，根据标签"user"，生成一个固定地址，每次运行测试时会生成相同的地址
    address user = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    // gas
    // uint256 constant GAS_PRICE = 1;

    // 钩子函数，在每个测试函数之前自动执行
    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run(); // 调用合约run方法，返回一个合约
        vm.deal(user, STARTING_BALANCE); // 给user设置金额
    }

    function testMiniumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        // us -> test -> deploy -> fund
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // 对以下逻辑取反
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(user); // 指定消息发送者的地址

        fundMe.fund{value: SEND_VALUE}(); // 发送交易，注意传参交易金额的格式

        uint256 amountFunded = fundMe.getAddressToAmountFunded(user);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(user);

        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, user);
    }

    modifier funded() {
        vm.prank(user);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(user);
        vm.expectRevert();

        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // vm.txGasPrice(GAS_PRICE); // 设置每单位所需支付的以太币数量
        // uint256 gasStart = gasleft();

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // console.log(gasUsed);

        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFormMultipleFunders() public funded {
        // address()类型转换时，无法直接从uint256转换为地址，需要从uint160转换
        uint160 numberOfFunders = 2;
        uint160 startingFunderIndex = 1; // 无法从0开始，address(0)是无效地址

        // 设置多个账户分别向合约转账
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(1), SEND_VALUE); // 模拟一个虚拟账户进行交易，并设置一个prank
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }

    function testCheaperWithdrawFormMultipleFunders() public funded {
        // address()类型转换时，无法直接从uint256转换为地址，需要从uint160转换
        uint160 numberOfFunders = 2;
        uint160 startingFunderIndex = 1; // 无法从0开始，address(0)是无效地址

        // 设置多个账户分别向合约转账
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(1), SEND_VALUE); // 模拟一个虚拟账户进行交易，并设置一个prank
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }
}
