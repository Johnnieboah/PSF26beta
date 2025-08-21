#!/usr/bin/env python3
"""
Contract Scaling System
Preserves real NFL contracts but scales values to match TEAM TOTALS reference
"""

import csv
import tempfile
import shutil

def main():
    print('⚖️  CONTRACT SCALING SYSTEM - PRESERVE REAL CONTRACTS')
    print('=' * 80)
    
    # Read TEAM TOTALS reference data
    team_totals_reference = {}
    with open('PSF26Tests/TEAM TOTALS - Sheet1.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team_abbr = row.get('TEAM', '').strip()
            total_cap_str = row.get('TOTAL CAPTOP-51', '').strip()
            
            if team_abbr and total_cap_str:
                try:
                    total_cap_clean = total_cap_str.replace('$', '').replace(',', '')
                    total_cap = int(total_cap_clean)
                    team_totals_reference[team_abbr] = total_cap
                except ValueError:
                    continue
    
    print(f'Loaded reference totals for {len(team_totals_reference)} teams')
    
    # Team name mapping from our CSV to TEAM TOTALS abbreviations
    team_mapping = {
        'Cleveland': 'CLE', 'San Francisco': 'SF', 'New York N': 'NYG',
        'Washington': 'WAS', 'Atlanta': 'ATL', 'Las Vegas': 'LV',
        'Jacksonville': 'JAX', 'Houston': 'HOU', 'Indianapolis': 'IND',
        'Dallas': 'DAL', 'Buffalo': 'BUF', 'Miami': 'MIA',
        'Chicago': 'CHI', 'Kansas City': 'KC', 'Green Bay': 'GB',
        'Tennessee': 'TEN', 'Baltimore': 'BAL', 'Carolina': 'CAR',
        'Los Angeles N': 'LAR', 'New England': 'NE', 'New Orleans': 'NO',
        'Philadelphia': 'PHI', 'Cincinnati': 'CIN', 'Minnesota': 'MIN',
        'Denver': 'DEN', 'Arizona': 'ARI', 'Detroit': 'DET',
        'Tampa Bay': 'TB', 'Seattle': 'SEA', 'Pittsburgh': 'PIT',
        'New York A': 'NYJ', 'Los Angeles A': 'LAC'
    }
    
    # Calculate current team totals and scaling factors
    current_team_totals = {}
    scaling_factors = {}
    
    print('\n📊 CALCULATING SCALING FACTORS...')
    print('=' * 60)
    
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team = row.get('Team', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            
            if team and contract_apy_str:
                try:
                    contract_apy = float(contract_apy_str)
                    contract_apy_dollars = int(contract_apy * 1_000_000)
                    
                    if team not in current_team_totals:
                        current_team_totals[team] = 0
                    current_team_totals[team] += contract_apy_dollars
                except ValueError:
                    continue
    
    # Calculate scaling factors for each team
    print('Team Name           | Current Total | Reference Total | Scaling Factor')
    print('=' * 80)
    
    for team_name, team_abbr in team_mapping.items():
        if team_name in current_team_totals and team_abbr in team_totals_reference:
            current_total = current_team_totals[team_name]
            reference_total = team_totals_reference[team_abbr]
            
            # Calculate scaling factor (reference / current)
            scaling_factor = reference_total / current_total if current_total > 0 else 1.0
            
            # Limit scaling factor to reasonable bounds (0.5 to 1.5)
            scaling_factor = max(0.5, min(1.5, scaling_factor))
            
            scaling_factors[team_name] = scaling_factor
            
            print(f'{team_name:<20} | ${current_total:>12,} | ${reference_total:>14,} | {scaling_factor:>6.3f}')
    
    # Now apply scaling while preserving real contracts
    print(f'\n🔧 APPLYING SCALING TO PRESERVE REAL CONTRACTS...')
    
    input_file = 'PFL2025DATA_ENHANCED.csv'
    temp_file = 'PFL2025DATA_ENHANCED_scaled.csv'
    
    players_scaled = 0
    players_preserved = 0
    total_players = 0
    
    with open(input_file, 'r', encoding='utf-8') as infile, open(temp_file, 'w', encoding='utf-8', newline='') as outfile:
        reader = csv.DictReader(infile)
        writer = csv.DictWriter(outfile, fieldnames=reader.fieldnames)
        writer.writeheader()
        
        for row in reader:
            total_players += 1
            team = row.get('Team', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            
            if team and contract_apy_str and team in scaling_factors:
                try:
                    # Get current contract values
                    current_apy = float(contract_apy_str)
                    current_total = float(row.get('contractTotalValue_M', '0'))
                    current_guaranteed = float(row.get('contractTotalGuaranteed_M', '0'))
                    
                    # Apply scaling factor
                    scaling_factor = scaling_factors[team]
                    scaled_apy = current_apy * scaling_factor
                    scaled_total = current_total * scaling_factor
                    scaled_guaranteed = current_guaranteed * scaling_factor
                    
                    # Update the row with scaled values
                    row['contractAPY_M'] = f"{scaled_apy:.2f}"
                    row['contractTotalValue_M'] = f"{scaled_total:.2f}"
                    row['contractTotalGuaranteed_M'] = f"{scaled_guaranteed:.2f}"
                    
                    players_scaled += 1
                    
                    # Show first few examples
                    if players_scaled <= 10:
                        print(f'Scaled: {row.get("firstName", "")} {row.get("lastName", "")} ({team})')
                        print(f'  → APY: ${current_apy:.2f}M → ${scaled_apy:.2f}M (factor: {scaling_factor:.3f})')
                except ValueError:
                    players_preserved += 1
            else:
                players_preserved += 1
            
            writer.writerow(row)
    
    # Replace the original file
    shutil.move(temp_file, input_file)
    
    print(f'\n✅ CONTRACT SCALING COMPLETE!')
    print(f'Total players processed: {total_players}')
    print(f'Players with scaled contracts: {players_scaled}')
    print(f'Players preserved unchanged: {players_preserved}')
    print(f'Updated file: {input_file}')
    
    # Verify the scaling worked
    print(f'\n🔍 VERIFYING SCALING RESULTS...')
    verify_scaling_results()

def verify_scaling_results():
    """Verify that the scaling brought team totals in line with reference data"""
    # Read TEAM TOTALS reference data again
    team_totals_reference = {}
    with open('PSF26Tests/TEAM TOTALS - Sheet1.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team_abbr = row.get('TEAM', '').strip()
            total_cap_str = row.get('TOTAL CAPTOP-51', '').strip()
            
            if team_abbr and total_cap_str:
                try:
                    total_cap_clean = total_cap_str.replace('$', '').replace(',', '')
                    total_cap = int(total_cap_clean)
                    team_totals_reference[team_abbr] = total_cap
                except ValueError:
                    continue
    
    # Team name mapping
    team_mapping = {
        'Cleveland': 'CLE', 'San Francisco': 'SF', 'New York N': 'NYG',
        'Washington': 'WAS', 'Atlanta': 'ATL', 'Las Vegas': 'LV',
        'Jacksonville': 'JAX', 'Houston': 'HOU', 'Indianapolis': 'IND',
        'Dallas': 'DAL', 'Buffalo': 'BUF', 'Miami': 'MIA',
        'Chicago': 'CHI', 'Kansas City': 'KC', 'Green Bay': 'GB',
        'Tennessee': 'TEN', 'Baltimore': 'BAL', 'Carolina': 'CAR',
        'Los Angeles N': 'LAR', 'New England': 'NE', 'New Orleans': 'NO',
        'Philadelphia': 'PHI', 'Cincinnati': 'CIN', 'Minnesota': 'MIN',
        'Denver': 'DEN', 'Arizona': 'ARI', 'Detroit': 'DET',
        'Tampa Bay': 'TB', 'Seattle': 'SEA', 'Pittsburgh': 'PIT',
        'New York A': 'NYJ', 'Los Angeles A': 'LAC'
    }
    
    # Calculate new team totals after scaling
    new_team_totals = {}
    
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team = row.get('Team', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            
            if team and contract_apy_str:
                try:
                    contract_apy = float(contract_apy_str)
                    contract_apy_dollars = int(contract_apy * 1_000_000)
                    
                    if team not in new_team_totals:
                        new_team_totals[team] = 0
                    new_team_totals[team] += contract_apy_dollars
                except ValueError:
                    continue
    
    # Show comparison
    print('📊 SCALING VERIFICATION: New Totals vs Reference')
    print('=' * 80)
    print('Team Name           | New Total     | Reference Total | Difference | % Diff')
    print('=' * 80)
    
    total_difference = 0
    teams_compared = 0
    
    for team_name, team_abbr in team_mapping.items():
        if team_name in new_team_totals and team_abbr in team_totals_reference:
            new_total = new_team_totals[team_name]
            reference_total = team_totals_reference[team_abbr]
            difference = new_total - reference_total
            percent_diff = (difference / reference_total) * 100 if reference_total > 0 else 0
            
            total_difference += abs(difference)
            teams_compared += 1
            
            print(f'{team_name:<20} | ${new_total:>12,} | ${reference_total:>14,} | ${difference:>10,} | {percent_diff:>6.1f}%')
    
    print('=' * 80)
    print(f'Teams compared: {teams_compared}')
    print(f'Average absolute difference: ${total_difference // teams_compared:,}')
    print(f'Total absolute difference: ${total_difference:,}')

if __name__ == "__main__":
    main()


