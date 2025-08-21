#!/usr/bin/env python3
"""
Salary Cap Check Script
Checks how many teams are over the NFL salary cap by comparing player contracts vs cap limit
"""

import csv

def main():
    print('💰 NFL SALARY CAP COMPLIANCE CHECK')
    print('=' * 80)
    
    # 2025 NFL Salary Cap
    NFL_SALARY_CAP = 255_400_000  # $255.4M
    
    print(f'📊 2025 NFL Salary Cap: ${NFL_SALARY_CAP:,}')
    print('=' * 80)
    
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
    
    # Calculate team totals from player contracts
    team_totals = {}
    
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team = row.get('Team', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            
            if team and contract_apy_str:
                try:
                    contract_apy = float(contract_apy_str)
                    contract_apy_dollars = int(contract_apy * 1_000_000)
                    
                    if team not in team_totals:
                        team_totals[team] = 0
                    team_totals[team] += contract_apy_dollars
                except ValueError:
                    continue
    
    # Check salary cap compliance
    teams_over_cap = []
    teams_under_cap = []
    total_over_cap = 0
    total_under_cap = 0
    
    print('Team Name           | Team Abbr | Total Contracts | Salary Cap | Difference | Status')
    print('=' * 100)
    
    for team_name in sorted(team_totals.keys()):
        if team_name in team_mapping:
            team_abbr = team_mapping[team_name]
            total_contracts = team_totals[team_name]
            difference = total_contracts - NFL_SALARY_CAP
            
            if difference > 0:
                # Team is over the cap
                teams_over_cap.append((team_name, team_abbr, total_contracts, difference))
                total_over_cap += difference
                status = "🔴 OVER CAP"
            else:
                # Team is under the cap
                teams_under_cap.append((team_name, team_abbr, total_contracts, abs(difference)))
                total_under_cap += abs(difference)
                status = "✅ UNDER CAP"
            
            print(f'{team_name:<20} | {team_abbr:>9} | ${total_contracts:>14,} | ${NFL_SALARY_CAP:>10,} | ${difference:>10,} | {status}')
    
    print('=' * 100)
    
    # Summary statistics
    print(f'\n📈 SALARY CAP COMPLIANCE SUMMARY:')
    print(f'Teams over salary cap: {len(teams_over_cap)} out of {len(team_totals)} ({len(teams_over_cap)/len(team_totals)*100:.1f}%)')
    print(f'Teams under salary cap: {len(teams_under_cap)} out of {len(team_totals)} ({len(teams_under_cap)/len(team_totals)*100:.1f}%)')
    print(f'Total over cap: ${total_over_cap:,}')
    print(f'Total under cap: ${total_under_cap:,}')
    
    # Show teams over the cap
    if teams_over_cap:
        print(f'\n🔴 TEAMS OVER THE SALARY CAP:')
        print('=' * 60)
        
        # Sort by how much over the cap they are
        teams_over_cap.sort(key=lambda x: x[3], reverse=True)
        
        for i, (team_name, team_abbr, total, over_amount) in enumerate(teams_over_cap, 1):
            percent_over = (over_amount / NFL_SALARY_CAP) * 100
            print(f'{i:2}. {team_name} ({team_abbr}): ${over_amount:,} over cap ({percent_over:.1f}%)')
            print(f'    Total contracts: ${total:,} | Cap limit: ${NFL_SALARY_CAP:,}')
            print()
    
    # Show teams with most cap space
    if teams_under_cap:
        print(f'💰 TEAMS WITH MOST CAP SPACE:')
        print('=' * 60)
        
        # Sort by how much under the cap they are
        teams_under_cap.sort(key=lambda x: x[3], reverse=True)
        
        for i, (team_name, team_abbr, total, under_amount) in enumerate(teams_under_cap[:10], 1):
            percent_under = (under_amount / NFL_SALARY_CAP) * 100
            print(f'{i:2}. {team_name} ({team_abbr}): ${under_amount:,} under cap ({percent_under:.1f}%)')
            print(f'    Total contracts: ${total:,} | Cap space: ${under_amount:,}')
            print()
    
    # Check if any teams are significantly over the cap
    significantly_over_cap = [t for t in teams_over_cap if t[3] > 50_000_000]  # $50M over
    
    if significantly_over_cap:
        print(f'⚠️  TEAMS SIGNIFICANTLY OVER CAP (>$50M):')
        print('=' * 60)
        
        for team_name, team_abbr, total, over_amount in significantly_over_cap:
            percent_over = (over_amount / NFL_SALARY_CAP) * 100
            print(f'{team_name} ({team_abbr}): ${over_amount:,} over cap ({percent_over:.1f}%)')
            print(f'  This team needs major contract restructuring!')

if __name__ == "__main__":
    main()


