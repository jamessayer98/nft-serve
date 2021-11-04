pragma solidity ^0.8.7;

/// @title Governable Contract
/// @notice gives any contract a list of governors
contract Governable {
    constructor(string memory _Name) {
        address Owner = msg.sender;
        Governors[Owner] = Governor({
            Name: _Name,
            Governor_ID: Governor_ID_Seed
        });
        GovernorAddresses.push(Owner);

        emit GovernorAdded(Owner, Governor_ID_Seed, Owner);
        Governor_ID_Seed += 1;
    }

    event GovernorAdded(
        address indexed newGovernor,
        uint256 Governor_ID,
        address indexed Addedby
    );

    uint256 private Governor_ID_Seed = 1;
    address[] public GovernorAddresses;

    struct Governor {
        string Name;
        uint256 Governor_ID;
    }

    mapping(address => Governor) Governors;

    modifier onlyGovernor() {
        require(
            Governors[msg.sender].Governor_ID != 0,
            "Governable : caller must be a member of the Governors"
        );
        _;
    }

    function getGovernors() public view returns (address[] memory) {
        return GovernorAddresses;
    }

    function addGovernor(address _newGovernor, string memory _Name)
        public
        payable
        onlyGovernor
    {
        address Owner = msg.sender;

        require(
            Governors[_newGovernor].Governor_ID != 0,
            "governor already added"
        );

        Governors[_newGovernor] = Governor({
            Name: _Name,
            Governor_ID: Governor_ID_Seed
        });
        GovernorAddresses.push(_newGovernor);
        emit GovernorAdded(_newGovernor, Governor_ID_Seed, Owner);
        Governor_ID_Seed += 1;
    }

    function removeGovernor(uint256 governorsIndexToDelete)
        public
        payable
        onlyGovernor
    {
        if (governorsIndexToDelete >= GovernorAddresses.length) return;

        for (
            uint256 i = governorsIndexToDelete;
            i < GovernorAddresses.length - 1;
            i++
        ) {
            GovernorAddresses[i] = GovernorAddresses[i + 1];
        }
        GovernorAddresses[governorsIndexToDelete] = GovernorAddresses[
            GovernorAddresses.length - 1
        ];
        GovernorAddresses.pop();
    }

    function isGovernor(address _addr) public view returns (bool) {
        if (Governors[_addr].Governor_ID != 0) {
            return true;
        }
        return false;
    }
}
