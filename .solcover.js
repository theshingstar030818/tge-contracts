module.exports = {
    testCommand: 'truffle test',
    norpc: true,
    accounts:10,
    port:8545,
    copyPackages: ['zeppelin-solidity'],
    skipFiles: ['contracts/Migrations.sol', 'simpleVestingSubscription.sol']
};
