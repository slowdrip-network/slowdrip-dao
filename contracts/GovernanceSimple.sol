// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlLite} from "./lib/Utils.sol";

/// @notice Minimal proposal/vote/execute shell using address-weight (e.g., bonded stake via an off-chain snapshot or feeder).
/// For production, replace with OZ Governor + Timelock and ERC20Votes / stake snapshots.
contract GovernanceSimple is AccessControlLite {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    enum ProposalState { Pending, Active, Succeeded, Defeated, Queued, Executed, Canceled }

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes   data;
        uint64  start;
        uint64  end;
        uint64  eta;
        uint256 forVotes;
        uint256 againstVotes;
        ProposalState state;
    }

    uint64  public votingDelay  = 1 minutes;
    uint64  public votingPeriod = 3 days;
    uint64  public timelock     = 1 days;
    uint256 public quorum       = 1; // replace with proper voting power feed

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public propCount;

    event Proposed(uint256 id, address proposer, address target, bytes data);
    event Voted(uint256 id, address voter, bool support, uint256 weight);
    event Queued(uint256 id, uint64 eta);
    event Executed(uint256 id);
    event Canceled(uint256 id);

    constructor(address admin) {
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(keccak256("GOVERNANCE_ROLE"), address(this)); // let this contract act as governance role if modules trust it
    }

    // --- Replace this hook with a real weight source (e.g., BondingManager stake or ERC20Votes snapshot) ---
    function _votingWeight(address voter) internal view virtual returns (uint256) {
        // WARNING: placeholder weight = 1. Replace with integration.
        voter;
        return 1;
    }

    function propose(address target, uint256 value, bytes calldata data) external returns (uint256 id) {
        id = ++propCount;
        proposals[id] = Proposal({
            proposer: msg.sender,
            target: target,
            value: value,
            data: data,
            start: uint64(block.timestamp + votingDelay),
            end:   uint64(block.timestamp + votingDelay + votingPeriod),
            eta:   0,
            forVotes: 0,
            againstVotes: 0,
            state: ProposalState.Pending
        });
        emit Proposed(id, msg.sender, target, data);
    }

    function open(uint256 id) external {
        Proposal storage p = proposals[id];
        require(p.state == ProposalState.Pending, "BAD_STATE");
        require(block.timestamp >= p.start, "NOT_STARTED");
        p.state = ProposalState.Active;
    }

    function vote(uint256 id, bool support) external {
        Proposal storage p = proposals[id];
        require(p.state == ProposalState.Active, "NOT_ACTIVE");
        require(block.timestamp <= p.end, "VOTE_ENDED");
        require(!hasVoted[id][msg.sender], "ALREADY_VOTED");
        hasVoted[id][msg.sender] = true;

        uint256 w = _votingWeight(msg.sender);
        if (support) p.forVotes += w; else p.againstVotes += w;
        emit Voted(id, msg.sender, support, w);
    }

    function close(uint256 id) external {
        Proposal storage p = proposals[id];
        require(p.state == ProposalState.Active, "NOT_ACTIVE");
        require(block.timestamp > p.end, "NOT_ENDED");
        if (p.forVotes + p.againstVotes >= quorum && p.forVotes > p.againstVotes) {
            p.state = ProposalState.Succeeded;
        } else {
            p.state = ProposalState.Defeated;
        }
    }

    function queue(uint256 id) external {
        Proposal storage p = proposals[id];
        require(p.state == ProposalState.Succeeded, "NOT_SUCCEEDED");
        p.state = ProposalState.Queued;
        p.eta = uint64(block.timestamp + timelock);
        emit Queued(id, p.eta);
    }

    function execute(uint256 id) external payable {
        Proposal storage p = proposals[id];
        require(p.state == ProposalState.Queued, "NOT_QUEUED");
        require(block.timestamp >= p.eta, "TIMELOCK");
        p.state = ProposalState.Executed;
        (bool ok, ) = p.target.call{value: p.value}(p.data);
        require(ok, "EXEC_FAIL");
        emit Executed(id);
    }

    function cancel(uint256 id) external {
        Proposal storage p = proposals[id];
        require(msg.sender == p.proposer || hasRole(ADMIN_ROLE, msg.sender), "ONLY_PROP/ADMIN");
        require(p.state != ProposalState.Executed, "ALREADY_EXEC");
        p.state = ProposalState.Canceled;
        emit Canceled(id);
    }
}
