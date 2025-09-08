# Synthetic Asset Smart Contract

A robust Clarity smart contract for creating and managing synthetic assets backed by collateral on the Stacks blockchain.

## Overview

This contract enables users to create synthetic assets (derivatives) that track the price of real-world assets without requiring direct ownership. Users can mint synthetic assets by depositing collateral (STX tokens) and maintain positions through a collateralized debt position (CDP) system.

## Key Features

### 🏗️ Asset Management
- **Create Synthetic Assets**: Deploy new synthetic assets with custom names, symbols, and initial prices
- **Price Oracle Integration**: Authorized oracles can update asset prices in real-time
- **Asset Information**: Query detailed information about any synthetic asset

### 💰 Position Management
- **Open Positions**: Create collateralized positions to mint synthetic assets
- **Close Positions**: Burn synthetic assets and retrieve collateral
- **Add Collateral**: Increase collateral to improve position health
- **Balance Tracking**: Track individual user balances per synthetic asset

### ⚡ Liquidation System
- **Health Monitoring**: Real-time collateral ratio calculations
- **Automatic Liquidation**: Positions below 120% collateral ratio can be liquidated
- **Liquidation Rewards**: 10% penalty distributed to liquidators
- **Safety Thresholds**: 150% minimum collateral ratio for new positions

### 🔒 Security Features
- **Access Controls**: Owner-only functions and authorized oracle system
- **Emergency Controls**: Pause/unpause functionality for emergencies
- **Input Validation**: Comprehensive validation for all user inputs
- **Error Handling**: Detailed error codes for debugging

## Contract Constants

```clarity
MIN_COLLATERAL_RATIO: 150%    // Minimum collateral required
LIQUIDATION_RATIO: 120%       // Liquidation threshold
LIQUIDATION_PENALTY: 10%      // Penalty for liquidated positions
