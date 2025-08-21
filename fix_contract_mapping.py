#!/usr/bin/env python3
"""
Fix Contract Mapping Script
Uses overall rating, team, position, and age to properly map fictional players to real NFL contracts
"""

import csv
import tempfile
import shutil

def main():
    print('🔧 FIXING CONTRACT MAPPING USING OVERALL + TEAM + POSITION + AGE')
    print('=' * 80)
    
    # Read NFL Contracts.csv to get real contract data
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
            
            if team and pos and value and apy:
                # Clean up team name and convert values
                team_clean = team.split()[0]  # Take first part of team name
                try:
                    value_clean = int(value.replace('$', '').replace(',', ''))
                    apy_clean = int(apy.replace('$', '').replace(',', ''))
                    
                    # Create key for matching
                    key = (team_clean, pos, age)
                    if key not in nfl_contracts:
                        nfl_contracts[key] = []
                    nfl_contracts[key].append({
                        'name': player_name,
                        'value': value_clean,
                        'apy': apy_clean
                    })
                except ValueError:
                    continue
    
    print(f'Loaded {len(nfl_contracts)} unique contract combinations from NFL Contracts.csv')
    
    # Team name mapping from CSV to NFL Contracts
    team_mapping = {
        'Buffalo': 'BUF',
        'Miami': 'MIA', 
        'NewEngland': 'NE',
        'New York A': 'NYJ',
        'New York N': 'NYG',
        'Pittsburgh': 'PIT',
        'Cleveland': 'CLE',
        'Cincinnati': 'CIN',
        'Baltimore': 'BAL',
        'Tennessee': 'TEN',
        'Indianapolis': 'IND',
        'Houston': 'HOU',
        'Jacksonville': 'JAX',
        'Kansas City': 'KC',
        'Las Vegas': 'LV',
        'Denver': 'DEN',
        'Los Angeles A': 'LAC',
        'Los Angeles N': 'LAR',
        'Seattle': 'SEA',
        'San Francisco': 'SF',
        'Arizona': 'ARI',
        'Dallas': 'DAL',
        'Philadelphia': 'PHI',
        'Washington': 'WAS',
        'Chicago': 'CHI',
        'Detroit': 'DET',
        'Green Bay': 'GB',
        'Minnesota': 'MIN',
        'Atlanta': 'ATL',
        'Carolina': 'CAR',
        'New Orleans': 'NO',
        'Tampa Bay': 'TB'
    }
    
    # Position mapping for better matching
    position_mapping = {
        'QB': 'QB',
        'HB': 'RB',
        'FB': 'FB',
        'WR': 'WR',
        'TE': 'TE',
        'LT': 'LT',
        'LG': 'LG',
        'C': 'C',
        'RG': 'RG',
        'RT': 'RT',
        'LE': 'DE',
        'RE': 'DE',
        'DT': 'DT',
        'LOLB': 'OLB',
        'MLB': 'ILB',
        'ROLB': 'OLB',
        'CB': 'CB',
        'FS': 'S',
        'SS': 'S',
        'K': 'K',
        'P': 'P'
    }
    
    # Read and fix the enhanced CSV
    input_file = 'PFL2025DATA_ENHANCED.csv'
    temp_file = 'PFL2025DATA_ENHANCED_fixed.csv'
    
    players_fixed = 0
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
                
                # Try to find matching contract
                contract_key = (nfl_team, nfl_pos, age)
                matching_contracts = nfl_contracts.get(contract_key, [])
                
                if matching_contracts:
                    # Find best contract based on overall rating
                    best_contract = None
                    best_score = 0
                    
                    for contract in matching_contracts:
                        # Score based on how well the contract matches the player's overall
                        # Higher overall players should get higher contracts
                        overall_int = int(overall)
                        if overall_int >= 95:  # Elite players
                            if contract['apy'] >= 20_000_000:  # $20M+
                                score = 100
                            elif contract['apy'] >= 15_000_000:  # $15M+
                                score = 80
                            else:
                                score = 40
                        elif overall_int >= 90:  # Pro Bowl level
                            if contract['apy'] >= 15_000_000:  # $15M+
                                score = 100
                            elif contract['apy'] >= 10_000_000:  # $10M+
                                score = 80
                            else:
                                score = 50
                        elif overall_int >= 85:  # Starter level
                            if contract['apy'] >= 8_000_000:  # $8M+
                                score = 100
                            elif contract['apy'] >= 5_000_000:  # $5M+
                                score = 80
                            else:
                                score = 60
                        else:  # Backup/developmental
                            if contract['apy'] >= 3_000_000:  # $3M+
                                score = 100
                            elif contract['apy'] >= 1_000_000:  # $1M+
                                score = 80
                            else:
                                score = 70
                        
                        if score > best_score:
                            best_score = score
                            best_contract = contract
                    
                    if best_contract:
                        # Apply the real contract
                        row['contractYears'] = '4'  # Standard NFL contract length
                        row['contractTotalValue_M'] = f"{best_contract['value'] / 1_000_000:.2f}"
                        row['contractAPY_M'] = f"{best_contract['apy'] / 1_000_000:.2f}"
                        row['contractTotalGuaranteed_M'] = f"{best_contract['value'] * 0.4 / 1_000_000:.2f}"  # 40% guaranteed
                        players_fixed += 1
                        
                        if players_fixed <= 10:  # Show first 10 fixes
                            print(f'Fixed: {row.get("firstName", "")} {row.get("lastName", "")} ({team} {position}) - OVR {overall}')
                            print(f'  → APY: ${best_contract["apy"] / 1_000_000:.2f}M (was: {row.get("contractAPY_M", "N/A")})')
                
                # If no exact match, use realistic contract based on overall rating
                if not matching_contracts:
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
                    row['contractTotalGuaranteed_M'] = f"{apy * 0.3 / 1_000_000:.2f}"  # 30% guaranteed
            
            writer.writerow(row)
    
    # Replace the original file
    shutil.move(temp_file, input_file)
    
    print(f'\n✅ CONTRACT MAPPING FIXED!')
    print(f'Total players processed: {total_players}')
    print(f'Players with real NFL contracts: {players_fixed}')
    print(f'Players with realistic fallback contracts: {total_players - players_fixed}')
    print(f'Updated file: {input_file}')
    
    # Now let's verify the fix worked
    print(f'\n🔍 VERIFYING THE FIX...')
    verify_contracts()

def verify_contracts():
    """Verify that contracts are now properly varied"""
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        # Check the problematic teams
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
        
        print(f'\n📊 CONTRACT VERIFICATION RESULTS:')
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


