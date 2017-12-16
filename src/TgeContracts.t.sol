pragma solidity ^0.4.17;

import "ds-test/test.sol";

import "./TgeContracts.sol";

contract TgeContractsTest is DSTest {
    TgeContracts contracts;

    function setUp() public {
        contracts = new TgeContracts();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
