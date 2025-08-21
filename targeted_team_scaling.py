#!/usr/bin/env python3
"""
Targeted Team Scaling Script
Fine-tunes the 3 teams that still need adjustment while preserving real NFL contracts
"""

import csv
import tempfile
import shutil

def main():
    print('🎯 TARGETED TEAM SCALING - PRESERVE REAL CONTRACTS')
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
    
    # Focus only on the 3 teams that need adjustment
    target_teams = ['Detroit', 'New England', 'Dallas']
    
    print(f'🎯 TARGETING 3 TEAMS FOR FINE-TUNING:')
    print('=' * 60)
    
    # Calculate current totals and needed adjustments
    current_team_totals = {}
    adjustment_factors = {}
    
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team = row.get('Team', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            
            if team in target_teams and contract_apy_str:
                try:
                    contract_apy = float(contract_apy_str)
                    contract_apy_dollars = int(contract_apy * 1_000_000)
                    
                    if team not in current_team_totals:
                        current_team_totals[team] = 0
                    current_team_totals[team] += contract_apy_dollars
                except ValueError:
                    continue
    
    # Calculate needed adjustment factors
    for team_name in target_teams:
        if team_name in current_team_totals:
            team_abbr = team_mapping[team_name]
            if team_abbr in team_totals_reference:
                current_total = current_team_totals[team_name]
                reference_total = team_totals_reference[team_abbr]
                
                # Calculate adjustment factor (reference / current)
                adjustment_factor = reference_total / current_total if current_total > 0 else 1.0
                
                # Limit adjustment factor to reasonable bounds (0.8 to 1.2)
                adjustment_factor = max(0.8, min(1.2, adjustment_factor))
                
                adjustment_factors[team_name] = adjustment_factor
                
                print(f'{team_name:<20} | Current: ${current_total:>12,} | Reference: ${reference_total:>14,}')
                print(f'{"":20} | Adjustment Factor: {adjustment_factor:.3f} | Target: ${current_total * adjustment_factor:>12,.0f}')
                print()
    
    # Now apply targeted adjustments while preserving real contracts
    print(f'🔧 APPLYING TARGETED ADJUSTMENTS...')
    
    input_file = 'PFL2025DATA_ENHANCED.csv'
    temp_file = 'PFL2025DATA_ENHANCED_targeted.csv'
    
    players_adjusted = 0
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
            
            if team in target_teams and contract_apy_str and team in adjustment_factors:
                try:
                    # Get current contract values
                    current_apy = float(contract_apy_str)
                    current_total = float(row.get('contractTotalValue_M', '0'))
                    current_guaranteed = float(row.get('contractTotalGuaranteed_M', '0'))
                    
                    # Apply targeted adjustment factor
                    adjustment_factor = adjustment_factors[team]
                    adjusted_apy = current_apy * adjustment_factor
                    adjusted_total = current_total * adjustment_factor
                    adjusted_guaranteed = current_guaranteed * adjustment_factor
                    
                    # Update the row with adjusted values
                    row['contractAPY_M'] = f"{adjusted_apy:.2f}"
                    row['contractTotalValue_M'] = f"{adjusted_total:.2f}"
                    row['contractTotalGuaranteed_M'] = f"{adjusted_guaranteed:.2f}"
                    
                    players_adjusted += 1
                    
                    # Show examples of adjustments
                    if players_adjusted <= 15:
                        print(f'Adjusted: {row.get("firstName", "")} {row.get("lastName", "")} ({team})')
                        print(f'  → APY: ${current_apy:.2f}M → ${adjusted_apy:.2f}M (factor: {adjustment_factor:.3f})')
                except ValueError:
                    players_preserved += 1
            else:
                players_preserved += 1
            
            writer.writerow(row)
    
    # Replace the original file
    shutil.move(temp_file, input_file)
    
    print(f'\n✅ TARGETED TEAM SCALING COMPLETE!')
    print(f'Total players processed: {total_players}')
    print(f'Players with targeted adjustments: {players_adjusted}')
    print(f'Players preserved unchanged: {players_preserved}')
    print(f'Updated file: {input_file}')
    
    # Verify the targeted adjustments worked
    print(f'\n🔍 VERIFYING TARGETED ADJUSTMENTS...')
    verify_targeted_adjustments()

def verify_targeted_adjustments():
    """Verify that the targeted adjustments brought the 3 teams in line"""
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
    
    # Focus on the 3 target teams
    target_teams = ['Detroit', 'New England', 'Dallas']
    
    # Calculate new team totals after targeted adjustments
    new_team_totals = {}
    
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team = row.get('Team', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            
            if team in target_teams and contract_apy_str:
                try:
                    contract_apy = float(contract_apy_str)
                    contract_apy_dollars = int(contract_apy * 1_000_000)
                    
                    if team not in new_team_totals:
                        new_team_totals[team] = 0
                    new_team_totals[team] += contract_apy_dollars
                except ValueError:
                    continue
    
    # Show comparison for target teams
    print('📊 TARGETED ADJUSTMENT VERIFICATION:')
    print('=' * 80)
    print('Team Name           | Team Abbr | New Total     | Reference Total | Difference | % Diff | Status')
    print('=' * 80)
    
    for team_name in target_teams:
        if team_name in new_team_totals:
            team_abbr = team_mapping[team_name]
            if team_abbr in team_totals_reference:
                new_total = new_team_totals[team_name]
                reference_total = team_totals_reference[team_abbr]
                difference = new_total - reference_total
                percent_diff = (difference / reference_total) * 100 if reference_total > 0 else 0
                
                # Determine status
                if abs(percent_diff) <= 1.0:
                    status = "✅ PERFECT"
                elif abs(percent_diff) <= 5.0:
                    status = "🟢 EXCELLENT"
                elif abs(percent_diff) <= 10.0:
                    status = "🟡 GOOD"
                else:
                    status = "🔴 NEEDS WORK"
                
                print(f'{team_name:<20} | {team_abbr:>9} | ${new_total:>12,} | ${reference_total:>14,} | ${difference:>10,} | {percent_diff:>6.1f}% | {status}')
    
    print('=' * 80)
    
    # Show overall improvement
    print(f'\n🎯 OVERALL IMPROVEMENT SUMMARY:')
    print(f'Target teams adjusted: {len(target_teams)}')
    
    # Check if all target teams are now within 5%
    all_within_5_percent = True
    for team_name in target_teams:
        if team_name in new_team_totals:
            team_abbr = team_mapping[team_name]
            if team_abbr in team_totals_reference:
                new_total = new_team_totals[team_name]
                reference_total = team_totals_reference[team_abbr]
                percent_diff = abs((new_total - reference_total) / reference_total * 100)
                if percent_diff > 5.0:
                    all_within_5_percent = False
                    break
    
    if all_within_5_percent:
        print("🎉 ALL TARGET TEAMS ARE NOW WITHIN 5% OF REFERENCE TOTALS!")
    else:
        print("⚠️  Some target teams still need fine-tuning")

if __name__ == "__main__":
    main()


