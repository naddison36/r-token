pragma solidity ^0.4.20;

import '../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol';
import '../node_modules/zeppelin-solidity/contracts/token/ERC20/DetailedERC20.sol';
import './RegulatedToken.sol';
import './RegulatorService.sol';

/**
 * @title  On-chain RegulatorService implementation that aggregates other regulator services
 * @author Nick Addison
 */
contract AggregatedTokenRegulatorService is RegulatorService, Ownable
{
  RegulatorService[] services;

  event AddService(address serviceAddress);

  // Constructor that adds the initial regulator services
  function AggregatedTokenRegulatorService(address[] _services)
  {
    // Fail the transaction if any of the services could not be added
    require(setServices(_services));
  }

  /**
   * @notice Checks whether or not a trade should be approved
   *
   * @dev    This method calls back to the token contract specified by `_token` for
   *         information needed to enforce trade approval if needed
   *
   * @param  _token The address of the token to be transfered
   * @param  _spender The address of the spender of the token (unused in this implementation)
   * @param  _from The address of the sender account
   * @param  _to The address of the receiver account
   * @param  _amount The quantity of the token to trade
   *
   * @return `true` if the trade should be approved and  `false` if the trade should not be approved
   */
  function check(address _token, address _spender, address _from, address _to, uint256 _amount) public returns (uint8)
  {
    // for each regulatory service
    for(uint8 i=0; i < services.length; i++)
    {
        // check the transfer is valid
        uint8 result = services[i].check(_token, _spender, _from, _to, _amount);

        // stop looping through the services if the last check failed
        if (result > 0) {
          return result;
        }
    }

    // All services calls where successful so returning zero
    return 0;
  }

  // Adds new regulator token services to the a list of services that need to be checked
  function setServices(address[] _services) public
      onlyOwner()
      returns (bool)
  {
    for(uint8 i=0; i < _services.length; i++)
    {
        bool result = addService(_services[i]);
        if (result == false) {
          return false;
        }
    }

    return true;
  }

  // Adds a new Token Regulator Service
  function addService(address _service) public
      onlyOwner()
      returns (bool)
  {
    // address of regulatory service must be passed in
    require(_service != address(0));

    // check there is code at the specified regulatory service location (address)
    uint length;
    assembly { length := extcodesize(_service) }
    if (length == 0) {return false;}

    // TODO ideally there would be validation that the service implements the RegulatorService interface.
    // That is, the check function has been implemented by the contract at the _service address

    // Add the service to the list of services
    services.push(RegulatorService(_service));

    // emit an event for the new service being added
    AddService(_service);

    return true;
  }

  //TODO need a way to remove services. In the interum the service proxy can be used to point to a new aggregated token regulator service
}
