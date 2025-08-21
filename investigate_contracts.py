#!/usr/bin/env python3
"""
Contract Investigation Script
Analyzes teams with large salary discrepancies to find root causes
"""

import csv

def main():
    # Read the enhanced CSV file and analyze teams with biggest discrepancies
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        # Focus on the teams with biggest differences
        problem_teams = ['New York N', 'New York A', 'Buffalo', 'Minnesota', 'Detroit']
        team_analysis = {}
        
        for row in reader:
            team = row.get('Team', '').strip()
            if team not in problem_teams:
                continue
                
            if team not in team_analysis:
                team_analysis[team] = {
                    'player_count': 0,
                    'total_apy': 0,
                    'contracts': [],
                    'missing_contracts': 0,
                    'min_contract': float('inf'),
                    'max_contract': 0
                }
            
            team_analysis[team]['player_count'] += 1
            
            # Get contract APY
            contract_apy_str = row.get('contractAPY_M', '').strip()
            if contract_apy_str and contract_apy_str != '':
                try:
                    contract_apy = float(contract_apy_str)
                    team_analysis[team]['total_apy'] += contract_apy
                    team_analysis[team]['contracts'].append({
                        'name': f"{row.get('firstName', '')} {row.get('lastName', '')}",
                        'position': row.get('Position', ''),
                        'overall': row.get('overallRating', ''),
                        'apy': contract_apy
                    })
                    team_analysis[team]['min_contract'] = min(team_analysis[team]['min_contract'], contract_apy)
                    team_analysis[team]['max_contract'] = max(team_analysis[team]['max_contract'], contract_apy)
                except ValueError:
                    team_analysis[team]['missing_contracts'] += 1
            else:
                team_analysis[team]['missing_contracts'] += 1

    # Print detailed analysis for problem teams
    for team, data in team_analysis.items():
        print(f'\n🔍 DETAILED ANALYSIS: {team}')
        print('=' * 60)
        print(f'Total players: {data["player_count"]}')
        print(f'Players with contracts: {len(data["contracts"])}')
        print(f'Players missing contracts: {data["missing_contracts"]}')
        print(f'Total APY: ${data["total_apy"]:.2f}M')
        if data["contracts"]:
            print(f'Average APY: ${data["total_apy"] / len(data["contracts"]):.2f}M')
        if data['min_contract'] != float('inf'):
            print(f'Min contract: ${data["min_contract"]:.2f}M')
        print(f'Max contract: ${data["max_contract"]:.2f}M')
        
        if data['missing_contracts'] > 0:
            print(f'\n⚠️  WARNING: {data["missing_contracts"]} players missing contracts!')
        
        # Show top 5 highest paid players
        if data['contracts']:
            sorted_contracts = sorted(data['contracts'], key=lambda x: x['apy'], reverse=True)
            print(f'\n💰 TOP 5 HIGHEST PAID PLAYERS:')
            for i, contract in enumerate(sorted_contracts[:5], 1):
                print(f'{i}. {contract["name"]} ({contract["position"]}) - OVR {contract["overall"]} - ${contract["apy"]:.2f}M')

    # Now let's check the TEAM TOTALS reference data
    print('\n\n📊 REFERENCE DATA FROM TEAM TOTALS:')
    print('=' * 60)
    
    with open('PSF26Tests/TEAM TOTALS - Sheet1.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team_abbr = row.get('TEAM', '').strip()
            if team_abbr in ['NYG', 'NYJ', 'BUF', 'MIN', 'DET']:
                total_cap_str = row.get('TOTAL CAPTOP-51', '').strip()
                if total_cap_str and total_cap_str != '':
                    total_cap_clean = total_cap_str.replace('$', '').replace(',', '')
                    try:
                        total_cap = int(total_cap_clean)
                        print(f'{team_abbr}: ${total_cap:,} (${total_cap/1_000_000:.1f}M)')
                    except ValueError:
                        continue

if __name__ == "__main__":
    main()


