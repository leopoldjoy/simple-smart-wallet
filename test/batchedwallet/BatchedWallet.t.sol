// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "@forge-std/Test.sol";
import {BatchedWallet} from "@source/BatchedWallet.sol";
import {BatchedWalletFactory} from "@source/BatchedWalletFactory.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BatchedWalletTest
 * @notice The contract tests the functionalites of the BatchedWallet directly (without
 * relying directions via an EntryPoint contract)
 */
contract BatchedWalletTest is Test {
    BatchedWallet public bw;
    IEntryPoint public entryPoint;
    address public globalUser = makeAddr("globalUser");
    ERC20Mock public erc20mock;

    function setUp() public {
        bytes32 salt = bytes32(0);
        entryPoint = IEntryPoint(makeAddr("entryPoint"));

        BatchedWalletFactory bwFactory = new BatchedWalletFactory(address(entryPoint));

        vm.startPrank(globalUser);
        bw = bwFactory.createWallet(globalUser, salt);

        vm.deal(address(bw), 1 ether);
        vm.stopPrank();

        erc20mock = new ERC20Mock();
    }

    function testOwner() public{
        assertEq(bw.owner(), globalUser);
    }

    function testEntryPoint() public{
        assertEq(address(bw.entryPoint()), address(entryPoint));
    }

    function testExecute() public {
        address user = makeAddr("user");

        vm.startPrank(address(entryPoint));
        bw.execute(user, 0.2 ether, "");
        assertEq(user.balance, 0.2 ether);
        assertEq(address(bw).balance, 0.8 ether);
        vm.stopPrank();
    }

    function testExecuteFailWithWrongOwner() public {
        address user = makeAddr("user");

        vm.startPrank(user);
        vm.expectRevert();

        bw.execute(user, 0.5 ether, "");
        
        vm.stopPrank();
    }

    function testDepositETH() public {
        vm.deal(address(bw), 5 ether);
        assertEq(address(bw).balance, 5 ether);
    }

    function testERC20Mint() public {
        vm.startPrank(address(entryPoint));
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(bw), 2 ether);
        bw.execute(address(erc20mock), 0, funcData);
        assertEq(erc20mock.balanceOf(address(bw)), 2 ether);
        vm.stopPrank();
    }

    function testERC20Transfer() public {
        vm.startPrank(address(entryPoint));

        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(bw), 3 ether);
        bw.execute(address(erc20mock), 0, funcData);
        assertEq(erc20mock.balanceOf(address(bw)), 3 ether);

        address user = makeAddr("user");
        bytes memory transferFuncData = abi.encodeWithSelector(IERC20.transfer.selector, user, 2 ether); 
        bw.execute(address(erc20mock), 0, transferFuncData);
        assertEq(erc20mock.balanceOf(user), 2 ether);
        vm.stopPrank();
    }

    function testBatchERC20MintAndTransfer() public{
        address user = makeAddr("user");

        address [] memory dest = new address[](2);
        bytes [] memory data = new bytes[](2);
        dest[0] = address(erc20mock);
        dest[1] = address(erc20mock);
        data[0] = abi.encodeWithSelector(
            ERC20Mock.mint.selector, 
            address(bw), 
            3 ether);
        data[1] = abi.encodeWithSelector(
            IERC20.transfer.selector, 
            user, 
            2 ether);

        vm.startPrank(address(entryPoint));
        bw.executeBatch(dest, data);
        assertEq(erc20mock.balanceOf(address(bw)), 1 ether);
        assertEq(erc20mock.balanceOf(user), 2 ether);
        vm.stopPrank();
    }

    function testExecuteBatchWithValuesSet() public{
        address user = makeAddr("user");
        address user2 = makeAddr("user2");

        vm.deal(address(bw), 4 ether);
        assertEq(address(bw).balance, 4 ether);

        address [] memory dest = new address[](2);
        uint256 [] memory value = new uint256[](2);
        bytes [] memory data = new bytes[](2);
        dest[0] = user;
        dest[1] = user2;
        value[0] = 1.5 ether;
        value[1] = 1.5 ether;

        vm.startPrank(address(entryPoint));
        bw.executeBatch(dest, value, data);
        assertEq(address(bw).balance, 1 ether);
        assertEq(user.balance, 1.5 ether);
        assertEq(user2.balance, 1.5 ether);
        vm.stopPrank();
    }

    function testWithdrawERC20() public{
        vm.startPrank(address(entryPoint));
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(bw), 2.5 ether);
        bw.execute(address(erc20mock), 0, funcData);
        assertEq(erc20mock.balanceOf(address(bw)), 2.5 ether);

        bytes memory withdrawERC20FuncData = abi.encodeWithSelector(IERC20.transfer.selector, globalUser, 2.5 ether);
        bw.execute(address(erc20mock), 0, withdrawERC20FuncData);
        assertEq(erc20mock.balanceOf(globalUser), 2.5 ether);

        vm.stopPrank();
    }

    function testWithdrawETH() public{
        vm.startPrank(address(entryPoint));

        bw.execute(address(globalUser), 0.3 ether, "");
        assertEq(address(globalUser).balance, 0.3 ether);

        vm.stopPrank();
    }
}
