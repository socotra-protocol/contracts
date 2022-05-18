// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

interface IDelegateRegistry {
    // Using these events it is possible to process the events to build up reverse lookups.
    // The indeces allow it to be very partial about how to build this lookup (e.g. only for a specific delegate).
    event SetDelegate(
        address indexed delegator,
        bytes32 indexed id,
        address indexed delegate
    );
    event ClearDelegate(
        address indexed delegator,
        bytes32 indexed id,
        address indexed delegate
    );

    /// @dev Sets a delegate for the msg.sender and a specific id.
    ///      The combination of msg.sender and the id can be seen as a unique key.
    /// @param id Id for which the delegate should be set
    /// @param delegate Address of the delegate
    function setDelegate(bytes32 id, address delegate) external;

    /// @dev Clears a delegate for the msg.sender and a specific id.
    ///      The combination of msg.sender and the id can be seen as a unique key.
    /// @param id Id for which the delegate should be set
    function clearDelegate(bytes32 id) external;
}
