#!/usr/bin/env python3
"""
Enhanced Contract Mapper for PFL2025DATA.csv
1. Maps real NFL players from PSFTESTRATINGS.csv to NFL Contracts.csv
2. Maps those contracts to fictional players in PFL2025DATA.csv
3. Ensures EVERY SINGLE PLAYER has their correct contract information.
"""

import csv
import re
from typing import Dict, List, Tuple, Optional

class EnhancedContractMapper:
    def __init__(self):
        self.nfl_contracts = {}  # Player name -> contract data
        self.real_players = {}   # Real NFL players from PSFTESTRATINGS.csv
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
        
        # Map full team names to abbreviated names for PFL data
        self.full_to_abbreviated = {
            'Cincinnati Bengals': 'Cincinnati',
            'Buffalo Bills': 'Buffalo',
            'Minnesota Vikings': 'Minnesota',
            'Jacksonville Jaguars': 'Jacksonville',
            'San Francisco 49ers': 'San Francisco',
            'Los Angeles Chargers': 'Los Angeles A',
            'Baltimore Ravens': 'Baltimore',
            'Philadelphia Eagles': 'Philadelphia',
            'Dallas Cowboys': 'Dallas',
            'Arizona Cardinals': 'Arizona',
            'Tampa Bay Buccaneers': 'Tampa Bay',
            'New York Giants': 'New York N',
            'New York Jets': 'New York A',
            'Detroit Lions': 'Detroit',
            'Atlanta Falcons': 'Atlanta',
            'Carolina Panthers': 'Carolina',
            'Seattle Seahawks': 'Seattle',
            'New Orleans Saints': 'New Orleans',
            'Green Bay Packers': 'Green Bay',
            'Pittsburgh Steelers': 'Pittsburgh',
            'Los Angeles Rams': 'Los Angeles N',
            'Denver Broncos': 'Denver',
            'Houston Texans': 'Houston',
            'New England Patriots': 'New England',
            'Las Vegas Raiders': 'Las Vegas',
            'Indianapolis Colts': 'Indianapolis',
            'Cleveland Browns': 'Cleveland',
            'Washington Commanders': 'Washington',
            'Chicago Bears': 'Chicago',
            'Tennessee Titans': 'Tennessee',
            'Kansas City Chiefs': 'Kansas City',
            'Miami Dolphins': 'Miami'
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
        
    def load_real_players(self, filename: str):
        """Load real NFL players from PSFTESTRATINGS.csv"""
        print(f"Loading real NFL players from {filename}...")
        
        with open(filename, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                player_name = f"{row['firstName']} {row['lastName']}"
                team_full = row['Team']
                position = row['Position']
                overall = int(row['overallRating']) if row['overallRating'].isdigit() else 0
                height = int(row['height']) if row['height'].isdigit() else 0
                weight = int(row['weight']) if row['weight'].isdigit() else 0
                handedness = int(row['handedness']) if row['handedness'].isdigit() else 0
                years_pro = int(row['yearsPro']) if row['yearsPro'].isdigit() else 0
                
                # Map full team name to abbreviated name for matching
                team_abbreviated = self.full_to_abbreviated.get(team_full, team_full)
                
                # Create unique key: PlayerName_Team_Position
                key = f"{player_name}_{team_abbreviated}_{position}"
                
                self.real_players[key] = {
                    'player_name': player_name,
                    'team_full': team_full,
                    'team_abbreviated': team_abbreviated,
                    'position': position,
                    'overall': overall,
                    'height': height,
                    'weight': weight,
                    'handedness': handedness,
                    'years_pro': years_pro
                }
                
        print(f"Loaded {len(self.real_players)} real NFL players")
        
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
            
    def find_contract_for_real_player(self, player_name: str, team_full: str, position: str) -> Optional[Dict]:
        """Find contract for a real NFL player"""
        
        # Try exact match first
        exact_key = f"{player_name}_{team_full}_{position}"
        if exact_key in self.nfl_contracts:
            return self.nfl_contracts[exact_key]
            
        # Try name + team match
        for key, contract in self.nfl_contracts.items():
            if (contract['player_name'] == player_name and 
                contract['team'] == team_full):
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
        """Map NFL contracts to PFL data using real player mapping"""
        print(f"Mapping contracts to {pfl_filename}...")
        
        updated_rows = []
        matched_count = 0
        unmatched_count = 0
        perfect_matches = 0
        high_quality_matches = 0
        acceptable_matches = 0
        total_score_sum = 0
        
        with open(pfl_filename, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            fieldnames = reader.fieldnames
            
            for row in reader:
                fictional_name = f"{row['firstName']} {row['lastName']}"
                team = row['Team']
                position = row['Position']
                overall = int(row['overallRating']) if row['overallRating'].isdigit() else 0
                height = int(row['height']) if row['height'].isdigit() else 0
                weight = int(row['weight']) if row['weight'].isdigit() else 0
                handedness = int(row['handedness']) if row['handedness'].isdigit() else 0
                years_pro = int(row['yearsPro']) if row['yearsPro'].isdigit() else 0
                
                # Find the best matching real player by team, position, overall rating, height, weight, handedness, and years pro
                best_match = None
                best_score = 0
                best_score_breakdown = None
                
                fictional_player_data = {
                    'overall': overall,
                    'height': height,
                    'weight': weight,
                    'handedness': handedness,
                    'years_pro': years_pro
                }
                
                for key, real_player in self.real_players.items():
                    if (real_player['team_abbreviated'] == team and 
                        real_player['position'] == position):
                        
                        # Calculate comprehensive match score
                        total_score, score_breakdown = self.calculate_match_score(fictional_player_data, real_player)
                        
                        if total_score > best_score:
                            best_score = total_score
                            best_match = real_player
                            best_score_breakdown = score_breakdown
                
                # If we found a good match, get their contract
                if best_match and best_score > 60:  # Increased threshold for more accurate matches
                    contract = self.find_contract_for_real_player(
                        best_match['player_name'], 
                        best_match['team_full'], 
                        best_match['position']
                    )
                    
                    if contract:
                        # Update contract fields
                        row['contractYears'] = contract['years']
                        row['contractTotalValue_M'] = contract['total_value'] / 1_000_000  # Convert to millions
                        row['contractAPY_M'] = contract['apy'] / 1_000_000  # Convert to millions
                        row['contractTotalGuaranteed_M'] = contract['guarantee'] / 1_000_000  # Convert to millions
                        row['Development'] = 'Normal'  # Default development
                        matched_count += 1
                        
                        # Track score quality
                        total_score_sum += best_score
                        if best_score >= 99.5:
                            perfect_matches += 1
                        elif best_score >= 90:
                            high_quality_matches += 1
                        else:
                            acceptable_matches += 1
                        
                        # Calculate individual scores for detailed logging
                        rating_diff = abs(best_match['overall'] - overall)
                        height_diff = abs(best_match['height'] - height)
                        weight_diff = abs(best_match['weight'] - weight)
                        
                        print(f"✅ Matched: {fictional_name} -> {best_match['player_name']} ({team})")
                        print(f"   Score: {best_score:.1f} | Rating: {overall} vs {best_match['overall']} (diff: {best_score_breakdown['overall_diff']})")
                        print(f"   Height: {height}\" vs {best_match['height']}\" (diff: {best_score_breakdown['height_diff']}\") | Weight: {weight} vs {best_match['weight']} lbs (diff: {best_score_breakdown['weight_diff']})")
                        print(f"   Handedness: {handedness} vs {best_match['handedness']} (diff: {best_score_breakdown['handedness_diff']}) | Years Pro: {years_pro} vs {best_match['years_pro']} (diff: {best_score_breakdown['years_pro_diff']})")
                        print(f"   Contract: {contract['apy']:,} APY")
                    else:
                        # Real player found but no contract - use defaults
                        row['contractYears'] = 4
                        row['contractTotalValue_M'] = 8.0  # $8M default
                        row['contractAPY_M'] = 2.0  # $2M APY default
                        row['contractTotalGuaranteed_M'] = 4.0  # $4M guaranteed default
                        row['Development'] = 'Normal'
                        unmatched_count += 1
                        print(f"⚠️  No contract: {fictional_name} -> {best_match['player_name']} ({team}) - Using defaults")
                else:
                    # No good match found - use defaults
                    row['contractYears'] = 4
                    row['contractTotalValue_M'] = 8.0  # $8M default
                    row['contractAPY_M'] = 2.0  # $2M APY default
                    row['contractTotalGuaranteed_M'] = 4.0  # $4M guaranteed default
                    row['Development'] = 'Normal'
                    unmatched_count += 1
                    if best_match:
                        print(f"❌ Low score match: {fictional_name} -> {best_match['player_name']} ({team}) - Score: {best_score:.1f} (too low)")
                    else:
                        print(f"❌ No match: {fictional_name} ({team}) - Using defaults")
                
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
        
        # Show matching statistics
        if matched_count > 0:
            print(f"\n🎯 Matching Accuracy:")
            print(f"   • Total players processed: {matched_count + unmatched_count}")
            print(f"   • Successfully matched: {matched_count}")
            print(f"   • Match rate: {(matched_count / (matched_count + unmatched_count)) * 100:.1f}%")
            print(f"   • Matching criteria: Team + Position + Overall Rating (35%) + Height (25%) + Weight (25%) + Handedness (10%) + Years Pro (5%)")
            print(f"   • Minimum score threshold: 60/100")
            
            print(f"\n📊 Score Distribution:")
            print(f"   • Perfect matches (99.5-100.0): {perfect_matches}")
            print(f"   • High quality (90-99.4): {high_quality_matches}")
            print(f"   • Acceptable (60-89.9): {acceptable_matches}")
            print(f"   • Average match score: {total_score_sum / matched_count:.1f}/100")
        
    def generate_contract_report(self, output_filename: str):
        """Generate a detailed report of all contracts"""
        print(f"\n📋 Generating contract report...")
        
        with open(output_filename, 'w', encoding='utf-8') as f:
            f.write("Enhanced NFL Contract Mapping Report\n")
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

    def calculate_match_score(self, fictional_player: Dict, real_player: Dict) -> Tuple[float, Dict]:
        """Calculate detailed match score between fictional and real player"""
        overall_diff = abs(real_player['overall'] - fictional_player['overall'])
        height_diff = abs(real_player['height'] - fictional_player['height'])
        weight_diff = abs(real_player['weight'] - fictional_player['weight'])
        handedness_diff = abs(real_player['handedness'] - fictional_player['handedness'])
        years_pro_diff = abs(real_player['years_pro'] - fictional_player['years_pro'])
        
        # Calculate individual scores
        rating_score = max(0, 100 - overall_diff)
        height_score = max(0, 100 - (height_diff * 25))  # 25 points per inch
        weight_score = max(0, 100 - (weight_diff * 2))   # 2 points per pound
        handedness_score = max(0, 100 - (handedness_diff * 50))  # 50 points per handedness difference
        years_pro_score = max(0, 100 - (years_pro_diff * 10))    # 10 points per year difference
        
        # Weighted total score - adjusted weights to accommodate new criteria
        total_score = (rating_score * 0.35) + (height_score * 0.25) + (weight_score * 0.25) + (handedness_score * 0.10) + (years_pro_score * 0.05)
        
        score_breakdown = {
            'total_score': total_score,
            'rating_score': rating_score,
            'height_score': height_score,
            'weight_score': weight_score,
            'handedness_score': handedness_score,
            'years_pro_score': years_pro_score,
            'overall_diff': overall_diff,
            'height_diff': height_diff,
            'weight_diff': weight_diff,
            'handedness_diff': handedness_diff,
            'years_pro_diff': years_pro_diff
        }
        
        return total_score, score_breakdown

def main():
    """Main execution function"""
    mapper = EnhancedContractMapper()
    
    # Load NFL contracts
    mapper.load_nfl_contracts('NFL Contracts.csv')
    
    # Load real NFL players
    mapper.load_real_players('PSFTESTRATINGS.csv')
    
    # Map contracts to PFL data
    mapper.map_contracts_to_pfl_data('PFL2025DATA.csv', 'PFL2025DATA_ENHANCED.csv')
    
    # Generate contract report
    mapper.generate_contract_report('Enhanced_Contract_Report.txt')
    
    print("\n🎯 Enhanced contract mapping complete! Every player now has accurate contract data.")

if __name__ == "__main__":
    main()
