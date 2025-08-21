#!/usr/bin/env python3
"""
Team Totals Comparison Script
Lists every team's total from player contracts vs TEAM TOTALS reference
"""

import csv

def main():
    print('📊 COMPLETE TEAM TOTALS COMPARISON')
    print('=' * 100)
    
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
    
    # Calculate current team totals from our player contracts
    current_team_totals = {}
    
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
    
    # Display comprehensive comparison
    print('Team Name           | Team Abbr | Our Total     | Reference Total | Difference | % Diff | Status')
    print('=' * 100)
    
    total_difference = 0
    teams_compared = 0
    teams_within_1_percent = 0
    teams_within_5_percent = 0
    teams_within_10_percent = 0
    
    # Sort teams by absolute difference for better analysis
    team_differences = []
    
    for team_name, team_abbr in team_mapping.items():
        if team_name in current_team_totals and team_abbr in team_totals_reference:
            our_total = current_team_totals[team_name]
            reference_total = team_totals_reference[team_abbr]
            difference = our_total - reference_total
            percent_diff = (difference / reference_total) * 100 if reference_total > 0 else 0
            
            team_differences.append((team_name, team_abbr, our_total, reference_total, difference, percent_diff))
    
    # Sort by absolute difference (smallest to largest)
    team_differences.sort(key=lambda x: abs(x[4]))
    
    for team_name, team_abbr, our_total, reference_total, difference, percent_diff in team_differences:
        # Determine status
        if abs(percent_diff) <= 1.0:
            status = "✅ PERFECT"
            teams_within_1_percent += 1
        elif abs(percent_diff) <= 5.0:
            status = "🟢 EXCELLENT"
            teams_within_5_percent += 1
        elif abs(percent_diff) <= 10.0:
            status = "🟡 GOOD"
            teams_within_10_percent += 1
        else:
            status = "🔴 NEEDS WORK"
        
        total_difference += abs(difference)
        teams_compared += 1
        
        print(f'{team_name:<20} | {team_abbr:>9} | ${our_total:>12,} | ${reference_total:>14,} | ${difference:>10,} | {percent_diff:>6.1f}% | {status}')
    
    print('=' * 100)
    
    # Summary statistics
    print(f'\n📈 SUMMARY STATISTICS:')
    print(f'Teams compared: {teams_compared}')
    print(f'Teams within 1%: {teams_within_1_percent} ({teams_within_1_percent/teams_compared*100:.1f}%)')
    print(f'Teams within 5%: {teams_within_5_percent} ({teams_within_5_percent/teams_compared*100:.1f}%)')
    print(f'Teams within 10%: {teams_within_10_percent} ({teams_within_10_percent/teams_compared*100:.1f}%)')
    print(f'Average absolute difference: ${total_difference // teams_compared:,}')
    print(f'Total absolute difference: ${total_difference:,}')
    
    # Show teams that still need attention
    print(f'\n🔍 TEAMS THAT STILL NEED ATTENTION (>10% difference):')
    print('=' * 60)
    
    teams_needing_work = [t for t in team_differences if abs(t[5]) > 10.0]
    
    if teams_needing_work:
        for team_name, team_abbr, our_total, reference_total, difference, percent_diff in teams_needing_work:
            print(f'{team_name} ({team_abbr}): {percent_diff:+.1f}% difference')
            print(f'  Our total: ${our_total:,} | Reference: ${reference_total:,}')
            print(f'  Difference: ${difference:+,}')
            print()
    else:
        print("🎉 ALL TEAMS ARE WITHIN 10% OF REFERENCE TOTALS!")

if __name__ == "__main__":
    main()


