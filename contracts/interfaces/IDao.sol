//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IDao {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function lp() external view returns (address);

    function burnLp(
        address _recipient,
        uint256 _share,
        address[] memory _tokens,
        address[] memory _adapters,
        address[] memory _pools
    ) external returns (bool);

    function setLp(address _lp) external returns (bool);

    function quorum() external view returns (uint8);

    function executedTx(bytes32 _txHash) external view returns (bool);

    function mintable() external view returns (bool);

    function burnable() external view returns (bool);

    function numberOfPermitted() external view returns (uint256);

    function numberOfAdapters() external view returns (uint256);

    function executePermitted(
        address _target,
        bytes calldata _data,
        uint256 _value
    ) external returns (bool);

    function execute(
        address _target,
        bytes calldata _data,
        uint256 _value,
        uint256 _nonce,
        uint256 _timestamp,
        bytes[] memory _sigs
    ) external returns (bool);

    function getTxHash(
        address _target,
        bytes calldata _data,
        uint256 _value,
        uint256 _nonce,
        uint256 _timestamp
    ) external view returns (bytes32);

    struct ExecutedVoting {
        address target;
        bytes data;
        uint256 value;
        uint256 nonce;
        uint256 timestamp;
        uint256 executionTimestamp;
        bytes32 txHash;
        bytes[] sigs;
    }

    function getExecutedVoting()
        external
        view
        returns (ExecutedVoting[] memory);
}
