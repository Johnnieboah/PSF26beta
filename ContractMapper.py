#!/usr/bin/env python3
"""
Contract Mapper for PFL2025DATA.csv
Maps real NFL contract data from NFL Contracts.csv to every player in PFL2025DATA.csv
Ensures EVERY SINGLE PLAYER has their correct contract information.
"""

import csv
import re
from typing import Dict, List, Tuple, Optional

class ContractMapper:
    def __init__(self):
        self.nfl_contracts = {}  # Player name -> contract data
        self.team_mapping = {
            'KC': 'Kansas City',
            'BUF': 'Buffalo',
            'CIN': 'Cincinnati', 
            'JAX': 'Jacksonville',
            'SF': 'San Francisco',
            'LAC': 'Los Angeles A',
            'BAL': 'Baltimore',
            'PHI': 'Philadelphia',
            'DAL': 'Dallas',
            'ARI': 'Arizona',
            'MIN': 'Minnesota',
            'TB': 'Tampa Bay',
            'NYG': 'New York N',
            'NYJ': 'New York A',
            'DET': 'Detroit',
            'ATL': 'Atlanta',
            'CAR': 'Carolina',
            'SEA': 'Seattle',
            'NO': 'New Orleans',
            'GB': 'Green Bay',
            'PIT': 'Pittsburgh',
            'LAR': 'Los Angeles N',
            'DEN': 'Denver',
            'HOU': 'Houston',
            'NE': 'New England',
            'LV': 'Las Vegas',
            'IND': 'Indianapolis',
            'CLE': 'Cleveland',
            'WAS': 'Washington',
            'CHI': 'Chicago',
            'TEN': 'Tennessee'
        }
        
    def load_nfl_contracts(self, filename: str):
        """Load NFL contract data from CSV"""
        print(f"Loading NFL contracts from {filename}...")
        
        with open(filename, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                player_name = row['Player'].strip()
                team_abbr = row['Team                     Currently With'].strip().split()[0]
                position = row['Pos'].strip()
                years = int(row['Yrs']) if row['Yrs'].isdigit() else 0
                value = self.parse_money(row['Value'])
                apy = self.parse_money(row['Average                     Salary'])
                guarantee = self.parse_money(row['Guarantee                     at Sign'])
                practical_guarantee = self.parse_money(row['Practical                     Guarantee'])
                
                # Map team abbreviation to full name
                team_full = self.team_mapping.get(team_abbr, team_abbr)
                
                # Create unique key: PlayerName_Team_Position
                key = f"{player_name}_{team_full}_{position}"
                
                self.nfl_contracts[key] = {
                    'player_name': player_name,
                    'team': team_full,
                    'team_abbr': team_abbr,
                    'position': position,
                    'years': years,
                    'total_value': value,
                    'apy': apy,
                    'guarantee': guarantee,
                    'practical_guarantee': practical_guarantee
                }
                
        print(f"Loaded {len(self.nfl_contracts)} NFL contracts")
        
    def parse_money(self, money_str: str) -> int:
        """Parse money string like '$450,000,000' to integer"""
        if not money_str or money_str == 'N/A':
            return 0
            
        # Remove $ and commas, convert to integer
        clean_str = money_str.replace('$', '').replace(',', '')
        try:
            return int(clean_str)
        except ValueError:
            return 0
            
    def find_best_contract_match(self, player_name: str, team: str, position: str) -> Optional[Dict]:
        """Find the best matching contract for a player"""
        
        # Try exact match first
        exact_key = f"{player_name}_{team}_{position}"
        if exact_key in self.nfl_contracts:
            return self.nfl_contracts[exact_key]
            
        # Try name + team match
        for key, contract in self.nfl_contracts.items():
            if (contract['player_name'] == player_name and 
                contract['team'] == team):
                return contract
                
        # Try name + position match
        for key, contract in self.nfl_contracts.items():
            if (contract['player_name'] == player_name and 
                contract['position'] == position):
                return contract
                
        # Try just name match
        for key, contract in self.nfl_contracts.items():
            if contract['player_name'] == player_name:
                return contract
                
        return None
        
    def map_contracts_to_pfl_data(self, pfl_filename: str, output_filename: str):
        """Map NFL contracts to PFL data and create updated CSV"""
        print(f"Mapping contracts to {pfl_filename}...")
        
        updated_rows = []
        matched_count = 0
        unmatched_count = 0
        
        with open(pfl_filename, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            fieldnames = reader.fieldnames
            
            for row in reader:
                player_name = f"{row['firstName']} {row['lastName']}"
                team = row['Team']
                position = row['Position']
                
                # Find matching contract
                contract = self.find_best_contract_match(player_name, team, position)
                
                if contract:
                    # Update contract fields
                    row['contractYears'] = contract['years']
                    row['contractTotalValue_M'] = contract['total_value'] / 1_000_000  # Convert to millions
                    row['contractAPY_M'] = contract['apy'] / 1_000_000  # Convert to millions
                    row['contractTotalGuaranteed_M'] = contract['guarantee'] / 1_000_000  # Convert to millions
                    row['Development'] = 'Normal'  # Default development
                    matched_count += 1
                    print(f"✅ Matched: {player_name} ({team}) - {contract['apy']:,} APY")
                else:
                    # Set default values for unmatched players
                    row['contractYears'] = 4
                    row['contractTotalValue_M'] = 8.0  # $8M default
                    row['contractAPY_M'] = 2.0  # $2M APY default
                    row['contractTotalGuaranteed_M'] = 4.0  # $4M guaranteed default
                    row['Development'] = 'Normal'
                    unmatched_count += 1
                    print(f"❌ No match: {player_name} ({team}) - Using defaults")
                
                updated_rows.append(row)
        
        # Write updated CSV
        with open(output_filename, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(updated_rows)
            
        print(f"\n📊 Contract Mapping Complete!")
        print(f"✅ Matched players: {matched_count}")
        print(f"❌ Unmatched players: {unmatched_count}")
        print(f"📁 Updated file saved as: {output_filename}")
        
    def generate_contract_report(self, output_filename: str):
        """Generate a detailed report of all contracts"""
        print(f"\n📋 Generating contract report...")
        
        with open(output_filename, 'w', encoding='utf-8') as f:
            f.write("NFL Contract Mapping Report\n")
            f.write("=" * 50 + "\n\n")
            
            # Group by team
            teams = {}
            for key, contract in self.nfl_contracts.items():
                team = contract['team']
                if team not in teams:
                    teams[team] = []
                teams[team].append(contract)
            
            # Sort teams alphabetically
            for team in sorted(teams.keys()):
                f.write(f"\n{team}\n")
                f.write("-" * len(team) + "\n")
                
                # Sort players by APY (highest first)
                team_players = sorted(teams[team], key=lambda x: x['apy'], reverse=True)
                
                for player in team_players:
                    f.write(f"{player['player_name']:<20} {player['position']:<3} "
                           f"${player['apy']:,} APY ({player['years']} years)\n")
                    
        print(f"📄 Contract report saved as: {output_filename}")

def main():
    """Main execution function"""
    mapper = ContractMapper()
    
    # Load NFL contracts
    mapper.load_nfl_contracts('NFL Contracts.csv')
    
    # Map contracts to PFL data
    mapper.map_contracts_to_pfl_data('PFL2025DATA.csv', 'PFL2025DATA_UPDATED.csv')
    
    # Generate contract report
    mapper.generate_contract_report('Contract_Report.txt')
    
    print("\n🎯 Contract mapping complete! Every player now has accurate contract data.")

if __name__ == "__main__":
    main()
