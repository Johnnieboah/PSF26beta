#!/usr/bin/env python3
"""
Improved Contract Mapping Script
Uses fuzzy matching for age and position to maximize real NFL contract usage
"""

import csv
import tempfile
import shutil

def main():
    print('🔧 IMPROVING CONTRACT MAPPING WITH FUZZY MATCHING')
    print('=' * 80)
    
    # Read NFL Contracts.csv with more flexible matching
    nfl_contracts = {}
    with open('NFL Contracts.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            player_name = row.get('Player', '').strip()
            team = row.get('Team                     Currently With', '').strip()
            pos = row.get('Pos', '').strip()
            age = row.get('Age                     At Signing', '').strip()
            value = row.get('Value', '').strip()
            apy = row.get('Average                     Salary', '').strip()
            
            if team and pos and age and value and apy:
                # Clean up team name
                team_clean = team.split()[0]
                try:
                    value_clean = int(value.replace('$', '').replace(',', ''))
                    apy_clean = int(apy.replace('$', '').replace(',', ''))
                    age_int = int(age)
                    
                    # Store by team and position, with age info
                    key = (team_clean, pos)
                    if key not in nfl_contracts:
                        nfl_contracts[key] = []
                    nfl_contracts[key].append({
                        'name': player_name,
                        'age': age_int,
                        'value': value_clean,
                        'apy': apy_clean
                    })
                except ValueError:
                    continue
    
    print(f'Loaded {len(nfl_contracts)} team+position combinations from NFL Contracts.csv')
    
    # Team name mapping
    team_mapping = {
        'Buffalo': 'BUF', 'Miami': 'MIA', 'NewEngland': 'NE',
        'New York A': 'NYJ', 'New York N': 'NYG', 'Pittsburgh': 'PIT',
        'Cleveland': 'CLE', 'Cincinnati': 'CIN', 'Baltimore': 'BAL',
        'Tennessee': 'TEN', 'Indianapolis': 'IND', 'Houston': 'HOU',
        'Jacksonville': 'JAX', 'Kansas City': 'KC', 'Las Vegas': 'LV',
        'Denver': 'DEN', 'Los Angeles A': 'LAC', 'Los Angeles N': 'LAR',
        'Seattle': 'SEA', 'San Francisco': 'SF', 'Arizona': 'ARI',
        'Dallas': 'DAL', 'Philadelphia': 'PHI', 'Washington': 'WAS',
        'Chicago': 'CHI', 'Detroit': 'DET', 'Green Bay': 'GB',
        'Minnesota': 'MIN', 'Atlanta': 'ATL', 'Carolina': 'CAR',
        'New Orleans': 'NO', 'Tampa Bay': 'TB'
    }
    
    # Position mapping with flexibility
    position_mapping = {
        'QB': 'QB',
        'HB': 'RB', 'FB': 'RB',  # Group running backs
        'WR': 'WR',
        'TE': 'TE',
        'LT': 'LT', 'RT': 'RT', 'LG': 'LG', 'RG': 'RG', 'C': 'C',  # O-line
        'LE': 'DE', 'RE': 'DE', 'DT': 'DT',  # D-line
        'LOLB': 'OLB', 'ROLB': 'OLB', 'MLB': 'ILB',  # Linebackers
        'CB': 'CB',
        'FS': 'S', 'SS': 'S',  # Group safeties
        'K': 'K', 'P': 'P'
    }
    
    # Read and fix the enhanced CSV
    input_file = 'PFL2025DATA_ENHANCED.csv'
    temp_file = 'PFL2025DATA_ENHANCED_improved.csv'
    
    players_with_real_contracts = 0
    players_with_fuzzy_contracts = 0
    players_with_fallback_contracts = 0
    total_players = 0
    
    with open(input_file, 'r', encoding='utf-8') as infile, open(temp_file, 'w', encoding='utf-8', newline='') as outfile:
        reader = csv.DictReader(infile)
        writer = csv.DictWriter(outfile, fieldnames=reader.fieldnames)
        writer.writeheader()
        
        for row in reader:
            total_players += 1
            team = row.get('Team', '').strip()
            position = row.get('Position', '').strip()
            overall = row.get('overallRating', '').strip()
            age = row.get('age', '').strip()
            
            if team and position and overall and age:
                # Map team and position
                nfl_team = team_mapping.get(team, team)
                nfl_pos = position_mapping.get(position, position)
                
                # Try to find matching contract with fuzzy age matching
                contract_key = (nfl_team, nfl_pos)
                matching_contracts = nfl_contracts.get(contract_key, [])
                
                if matching_contracts:
                    try:
                        age_int = int(age)
                        
                        # Find best contract with age tolerance
                        best_contract = None
                        best_score = 0
                        age_tolerance = 3  # Allow ±3 years for matching
                        
                        for contract in matching_contracts:
                            age_diff = abs(contract['age'] - age_int)
                            
                            if age_diff <= age_tolerance:
                                # Score based on overall rating and age similarity
                                overall_int = int(overall)
                                
                                # Base score from overall rating
                                if overall_int >= 95:  # Elite
                                    base_score = 100
                                elif overall_int >= 90:  # Pro Bowl
                                    base_score = 80
                                elif overall_int >= 85:  # Starter
                                    base_score = 60
                                elif overall_int >= 80:  # Backup
                                    base_score = 40
                                else:  # Developmental
                                    base_score = 20
                                
                                # Age similarity bonus (closer age = higher score)
                                age_bonus = (age_tolerance - age_diff) * 10
                                total_score = base_score + age_bonus
                                
                                if total_score > best_score:
                                    best_score = total_score
                                    best_contract = contract
                        
                        if best_contract:
                            # Apply the real contract
                            row['contractYears'] = '4'
                            row['contractTotalValue_M'] = f"{best_contract['value'] / 1_000_000:.2f}"
                            row['contractAPY_M'] = f"{best_contract['apy'] / 1_000_000:.2f}"
                            row['contractTotalGuaranteed_M'] = f"{best_contract['value'] * 0.4 / 1_000_000:.2f}"
                            
                            if best_contract['age'] == age_int:
                                players_with_real_contracts += 1
                            else:
                                players_with_fuzzy_contracts += 1
                            
                            if players_with_real_contracts + players_with_fuzzy_contracts <= 10:
                                print(f'Matched: {row.get("firstName", "")} {row.get("lastName", "")} ({team} {position}) - OVR {overall}')
                                print(f'  → APY: ${best_contract["apy"] / 1_000_000:.2f}M (NFL age: {best_contract["age"]}, our age: {age_int})')
                        else:
                            # No age-appropriate contract found, use fallback
                            players_with_fallback_contracts += 1
                            apply_fallback_contract(row, overall)
                    
                    except ValueError:
                        players_with_fallback_contracts += 1
                        apply_fallback_contract(row, overall)
                else:
                    # No position match, use fallback
                    players_with_fallback_contracts += 1
                    apply_fallback_contract(row, overall)
            else:
                # Missing data, use fallback
                players_with_fallback_contracts += 1
                if overall:
                    apply_fallback_contract(row, overall)
            
            writer.writerow(row)
    
    # Replace the original file
    shutil.move(temp_file, input_file)
    
    print(f'\n✅ IMPROVED CONTRACT MAPPING COMPLETE!')
    print(f'Total players processed: {total_players}')
    print(f'Players with exact age matches: {players_with_real_contracts}')
    print(f'Players with fuzzy age matches: {players_with_fuzzy_contracts}')
    print(f'Players with fallback contracts: {players_with_fallback_contracts}')
    print(f'Total real NFL contracts used: {players_with_real_contracts + players_with_fuzzy_contracts}')
    print(f'Success rate: {((players_with_real_contracts + players_with_fuzzy_contracts) / total_players * 100):.1f}%')
    print(f'Updated file: {input_file}')
    
    # Verify the improvement
    print(f'\n🔍 VERIFYING IMPROVEMENT...')
    verify_improvement()

def apply_fallback_contract(row, overall):
    """Apply realistic fallback contract based on overall rating"""
    try:
        overall_int = int(overall)
        if overall_int >= 95:  # Elite
            apy = 25_000_000  # $25M
        elif overall_int >= 90:  # Pro Bowl
            apy = 15_000_000  # $15M
        elif overall_int >= 85:  # Starter
            apy = 8_000_000   # $8M
        elif overall_int >= 80:  # Backup
            apy = 3_000_000   # $3M
        else:  # Developmental
            apy = 1_000_000   # $1M
        
        row['contractYears'] = '3'
        row['contractTotalValue_M'] = f"{apy * 3 / 1_000_000:.2f}"
        row['contractAPY_M'] = f"{apy / 1_000_000:.2f}"
        row['contractTotalGuaranteed_M'] = f"{apy * 0.3 / 1_000_000:.2f}"
    except ValueError:
        pass

def verify_improvement():
    """Verify that the improvement worked"""
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        # Check the previously problematic teams
        problem_teams = ['New York N', 'New York A', 'Buffalo', 'Minnesota', 'Detroit']
        team_contracts = {}
        
        for row in reader:
            team = row.get('Team', '').strip()
            if team in problem_teams:
                if team not in team_contracts:
                    team_contracts[team] = []
                
                apy = row.get('contractAPY_M', '').strip()
                if apy:
                    try:
                        team_contracts[team].append(float(apy))
                    except ValueError:
                        continue
        
        print(f'\n📊 IMPROVED CONTRACT VERIFICATION:')
        print('=' * 50)
        
        for team, contracts in team_contracts.items():
            if contracts:
                unique_apys = len(set(contracts))
                min_apy = min(contracts)
                max_apy = max(contracts)
                avg_apy = sum(contracts) / len(contracts)
                
                print(f'{team}:')
                print(f'  Unique APY values: {unique_apys}')
                print(f'  APY range: ${min_apy:.2f}M - ${max_apy:.2f}M')
                print(f'  Average APY: ${avg_apy:.2f}M')
                print()

if __name__ == "__main__":
    main()


